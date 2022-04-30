#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -y  System name, default: system
  -u  Root user, default: root
  -s  Root password
  -e  Name of the database user to create
  -w  Database password of the user to create
  -b  Database name to grant the user rights to
  -g  Grant user super rights
  -c  Create initial database

Example: ${scriptName} -u root -s secret -e user -w password -b dbname -g -c
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
databaseVersion=
databaseRootUser=
databaseRootPassword=
databaseUser=
databasePassword=
databaseName=
grantSuperRights=
createDatabase=

while getopts hy:u:s:e:w:b:gc? option; do
  case "${option}" in
    h) usage; exit 1;;
    y) system=$(trim "$OPTARG");;
    u) databaseRootUser=$(trim "$OPTARG");;
    s) databaseRootPassword=$(trim "$OPTARG");;
    e) databaseUser=$(trim "$OPTARG");;
    w) databasePassword=$(trim "$OPTARG");;
    b) databaseName=$(trim "$OPTARG");;
    g) grantSuperRights="yes";;
    c) createDatabase="yes";;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${databaseRootUser}" ]]; then
  databaseRootUser="root"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  echo "No database root password specified!"
  exit 1
fi

if [[ -z "${grantSuperRights}" ]]; then
  grantSuperRights="no"
fi

if [[ -z "${createDatabase}" ]]; then
  createDatabase="no"
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "${currentPath}/../env.properties" ]]; then
  echo "No environment specified!"
  exit 1
fi

serverList=( $(ini-parse "${currentPath}/../env.properties" "yes" "system" "server") )
if [[ "${#serverList[@]}" -eq 0 ]]; then
  echo "No servers specified!"
  exit 1
fi

database=
databaseHost=

for server in "${serverList[@]}"; do
  database=$(ini-parse "${currentPath}/../env.properties" "no" "${server}" "database")
  if [[ -n "${database}" ]]; then
    serverType=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "type")
    if [[ "${serverType}" == "local" ]]; then
      echo "--- Creating database user on local server: ${server} ---"
      databaseHost="localhost"
    else
      echo "--- Creating database user on remote server: ${server} ---"
      databaseHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "host")
    fi
    break
  fi
done

if [[ -z "${databaseHost}" ]]; then
  echo "No database settings found"
  exit 1
fi

databaseType=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "type")
databaseVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "version")
databasePort=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "port")

if [[ -z "${databaseType}" ]]; then
  echo "No database type specified!"
  exit 1
fi

if [[ -z "${databaseVersion}" ]]; then
  echo "No database version specified!"
  exit 1
fi

if [[ -z "${databasePort}" ]]; then
  echo "No database port specified!"
  exit 1
fi

if [[ -z "${databaseUser}" ]]; then
  databaseUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "user")
else
  if [[ -z "${databaseUser}" ]]; then
    echo "No database user specified!"
    exit 1
  fi

  ini-set "${currentPath}/../env.properties" "yes" "${database}" user "${databaseUser}"
fi

if [[ -z "${databasePassword}" ]]; then
  databasePassword=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "password")
else
  if [[ -z "${databasePassword}" ]]; then
    echo "No database password specified!"
    exit 1
  fi

  ini-set "${currentPath}/../env.properties" "yes" "${database}" password "${databasePassword}"
fi

if [[ -z "${databaseName}" ]]; then
  databaseName=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "name")
else
  if [[ -z "${databaseName}" ]]; then
    echo "No database name specified!"
    exit 1
  fi

  ini-set "${currentPath}/../env.properties" "yes" "${database}" name "${databaseName}"
fi

if [[ "${databaseType}" == "mysql" ]] && [[ "${databaseVersion}" == "8.0" ]]; then
  cat <<EOF | tee "/tmp/create-user.sh" > /dev/null
#!/bin/bash -e

export MYSQL_PWD="${databaseRootPassword}"

echo "Adding user: '${databaseUser}'@'localhost'"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "CREATE USER '${databaseUser}'@'localhost' IDENTIFIED BY '${databasePassword}';"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT ALL ON ${databaseName}.* TO '${databaseUser}'@'localhost';"

if [[ "${grantSuperRights}" == "yes" ]]; then
    echo "Granting super rights to user: '${databaseUser}'@'localhost'"
    mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT SUPER ON *.* TO '${databaseUser}'@'localhost';"
fi

echo "Adding user: '${databaseUser}'@'127.0.0.1'"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "CREATE USER '${databaseUser}'@'127.0.0.1' IDENTIFIED BY '${databasePassword}';"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT ALL ON ${databaseName}.* TO '${databaseUser}'@'127.0.0.1';"

if [[ "${grantSuperRights}" == "yes" ]]; then
    echo "Granting super rights to user: '${databaseUser}'@'127.0.0.1'"
    mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT SUPER ON *.* TO '${databaseUser}'@'127.0.0.1';"
fi

echo "Adding user: '${databaseUser}'@'%'"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "CREATE USER '${databaseUser}'@'%' IDENTIFIED BY '${databasePassword}';"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT ALL ON ${databaseName}.* TO '${databaseUser}'@'%';"

if [[ "${grantSuperRights}" == "yes" ]]; then
    echo "Granting super rights to user: '${databaseUser}'@'%'"
    mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT SUPER ON *.* TO '${databaseUser}'@'%';"
fi

echo "Flushing privileges"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "FLUSH PRIVILEGES;"

if [[ "${createDatabase}" == "yes" ]]; then
  export MYSQL_PWD="${databasePassword}"

  echo "Dropping database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS ${databaseName};"

  echo "Creating database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "CREATE DATABASE ${databaseName} CHARACTER SET utf8 COLLATE utf8_general_ci;";
fi
EOF
else
  cat <<EOF | tee "/tmp/create-user.sh" > /dev/null
#!/bin/bash -e

export MYSQL_PWD="${databaseRootPassword}"

echo "Adding user: '${databaseUser}'@'localhost'"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT ALL ON ${databaseName}.* TO '${databaseUser}'@'localhost' identified by '${databasePassword}' WITH GRANT OPTION;"
if [[ "${databaseVersion}" == "5.7" ]]; then
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "ALTER USER '${databaseUser}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${databasePassword}';"
fi

if [[ "${grantSuperRights}" == "yes" ]]; then
    echo "Granting super rights to user: '${databaseUser}'@'localhost'"
    mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT SUPER ON *.* TO '${databaseUser}'@'localhost';"
fi

echo "Adding user: '${databaseUser}'@'%'"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT ALL ON ${databaseName}.* TO '${databaseUser}'@'%' identified by '${databasePassword}' WITH GRANT OPTION;"
if [[ "${databaseVersion}" == "5.7" ]]; then
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "ALTER USER '${databaseUser}'@'%' IDENTIFIED WITH mysql_native_password BY '${databasePassword}';"
fi

if [[ "${grantSuperRights}" == "yes" ]]; then
    echo "Granting super rights to user: '${databaseUser}'@'%'"
    mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "GRANT SUPER ON *.* TO '${databaseUser}'@'%';"
fi

echo "Flushing privileges"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseRootUser}" -e "FLUSH PRIVILEGES;"

if [[ "${createDatabase}" == "yes" ]]; then
  export MYSQL_PWD="${databasePassword}"

  echo "Dropping database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS ${databaseName};"

  echo "Creating database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "CREATE DATABASE ${databaseName} CHARACTER SET utf8 COLLATE utf8_general_ci;";
fi
EOF
fi

chmod +x /tmp/create-user.sh

if [[ "${serverType}" == "local" ]] || [[ "${serverType}" == "docker" ]]; then
  /tmp/create-user.sh
  rm -rf /tmp/create-user.sh
elif [[ "${serverType}" == "ssh" ]]; then
  sshUser="$(whoami)"
  echo "Copying script to ${sshUser}@${databaseHost}:/tmp/create-user.sh"
  scp -q "/tmp/create-user.sh" "${sshUser}@${databaseHost}:/tmp/create-user.sh"
  ssh "${sshUser}@${databaseHost}" "/tmp/create-user.sh"
  ssh "${sshUser}@${databaseHost}" "rm -rf /tmp/create-user.sh"
else
  echo "Invalid database server type: ${serverType}"
  exit 1
fi

#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -o  Database host, default: localhost
  -p  Database port, default: 3306
  -u  Name of the database user to create
  -s  Database password of the user to create
  -b  Database name to grant the user rights to
  -t  Database type
  -v  Database version
  -r  Root user, default: root
  -w  Root password
  -g  Grant user super rights, default: no
  -c  Create initial database, default: no

Example: ${scriptName} -u newuser -s password -b database -t mysql -v 5.7 -w secret
EOF
}

trim()
{
  echo -n "$1" | xargs
}

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
databaseType=
databaseVersion=
databaseRootUser=
databaseRootPassword=
grantSuperRights=
createDatabase=

while getopts ho:p:u:s:b:t:v:r:w:g:c:? option; do
  case "${option}" in
    h) usage; exit 1;;
    o) databaseHost=$(trim "$OPTARG");;
    p) databasePort=$(trim "$OPTARG");;
    u) databaseUser=$(trim "$OPTARG");;
    s) databasePassword=$(trim "$OPTARG");;
    b) databaseName=$(trim "$OPTARG");;
    t) databaseType=$(trim "$OPTARG");;
    v) databaseVersion=$(trim "$OPTARG");;
    r) databaseRootUser=$(trim "$OPTARG");;
    w) databaseRootPassword=$(trim "$OPTARG");;
    g) grantSuperRights=$(trim "$OPTARG");;
    c) createDatabase=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${databaseHost}" ]]; then
  databaseHost="localhost"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort=3306
fi

if [[ -z "${databaseUser}" ]]; then
  echo "No database user specified!"
  exit 1
fi

if [[ -z "${databasePassword}" ]]; then
  echo "No database password specified!"
  exit 1
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name specified!"
  exit 1
fi

if [[ -z "${databaseType}" ]]; then
  echo "No database type specified!"
  exit 1
fi

if [[ -z "${databaseVersion}" ]]; then
  echo "No database version specified!"
  exit 1
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

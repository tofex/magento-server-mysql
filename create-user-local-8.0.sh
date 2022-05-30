#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -v  Database version
  -u  Root user, default: root
  -s  Root password
  -o  Database host, default: localhost
  -p  Database port, default: 3306
  -e  Name of the database user to create
  -w  Database password of the user to create
  -b  Database name to grant the user rights to
  -g  Grant user super rights, default: no
  -c  Create initial database, default: no

Example: ${scriptName} -s secret
EOF
}

trim()
{
  echo -n "$1" | xargs
}

databaseVersion=
databaseRootUser=
databaseRootPassword=
databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
grantSuperRights=
createDatabase=

while getopts hv:u:s:o:p:e:w:b:g:c:? option; do
  case "${option}" in
    h) usage; exit 1;;
    v) databaseVersion=$(trim "$OPTARG");;
    u) databaseRootUser=$(trim "$OPTARG");;
    s) databaseRootPassword=$(trim "$OPTARG");;
    o) databaseHost=$(trim "$OPTARG");;
    p) databasePort=$(trim "$OPTARG");;
    e) databaseUser=$(trim "$OPTARG");;
    w) databasePassword=$(trim "$OPTARG");;
    b) databaseName=$(trim "$OPTARG");;
    g) grantSuperRights=$(trim "$OPTARG");;
    c) createDatabase=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
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

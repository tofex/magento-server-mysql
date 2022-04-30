#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -n  Name of database to import to

Example: ${scriptName} -m dev -a -u
EOF
}

trim()
{
  echo -n "$1" | xargs
}

databaseName=

while getopts hn:u? option; do
  case ${option} in
    h) usage; exit 1;;
    n) databaseName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${databaseName}" ]]; then
  echo "No database name defined!"
  exit 1
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

databaseHostName="35.198.181.44"
databasePort="3306"
databaseUserName="projekte"
databasePassword="projekte"

export MYSQL_PWD="${databasePassword}"

echo "Adding stored procedure"
mysql -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} "${databaseName}" < "${currentPath}/anonymize.sql"

echo "Calling stored procedure"
mysql -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} "${databaseName}" -e "CALL anonymizeMagento('${databaseName}');"

echo "Dropping stored procedure"
mysql -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} "${databaseName}" -e "DROP PROCEDURE anonymizeMagento;"

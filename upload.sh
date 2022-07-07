#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -d  Date of the file
  -m  Mode (dev/test)
  -n  Name of database to import to

Example: ${scriptName} -m dev -d 2018-06-05 -n magento
EOF
}

trim()
{
  echo -n "$1" | xargs
}

date=
mode=
databaseName=

while getopts hd:m:n:? option; do
  case ${option} in
    h) usage; exit 1;;
    d) date=$(trim "$OPTARG");;
    m) mode=$(trim "$OPTARG");;
    n) databaseName=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${mode}" ]]; then
  echo "No mode defined!"
  exit 1
fi

if [[ -z "${date}" ]]; then
  echo "No date defined!"
  exit 1
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name defined!"
  exit 1
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

dumpPath="${currentPath}/../var/mysql/dumps"

cd "${dumpPath}"

importSource=mysql-${mode}-${date}.sql

if [[ ! -f "${importSource}" ]]; then
  echo "Invalid import source: ${importSource}!"
  exit 1
fi

echo "Preparing upload"
cat "${importSource}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e '/^ALTER\sDATABASE/d' > upload.sql

databaseHostName="35.198.181.44"
databasePort="3306"
databaseUserName="projekte"
databasePassword="projekte"

export MYSQL_PWD="${databasePassword}"

echo "Dropping database: ${databaseName}"
mysql -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} -e "DROP DATABASE IF EXISTS \`${databaseName}\`;"

echo "Creating database: ${databaseName}"
mysql -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} -e "CREATE DATABASE \`${databaseName}\` CHARACTER SET utf8 COLLATE utf8_general_ci;";

echo "Uploading to database: ${databaseName}"
mysql -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} --init-command="SET SESSION FOREIGN_KEY_CHECKS=0;" "${databaseName}" < upload.sql

rm -rf upload.sql

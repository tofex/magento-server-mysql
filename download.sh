#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help              Show this message
  --dumpFile          File to store the dump in
  --databaseHost      Host name of database, default: 35.198.181.44
  --databasePort      Port of database, default: 3306
  --databaseUser      User name of database, default: projekte
  --databasePassword  Password of database, default: projekte
  --databaseName      Name of database to import to
  --remove            Remove the database after download (yes/no), default: no

Example: ${scriptName} --dump /tmp/download.sql --databaseName magentodb
EOF
}

dumpFile=
databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
remove=

if [[ -f "${currentPath}/../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${dumpFile}" ]]; then
  echo "No dump file defined!"
  exit 1
fi

if [[ -z "${databaseHost}" ]]; then
  databaseHost="35.198.181.44"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseUser}" ]]; then
  databaseUser="projekte"
fi

if [[ -z "${databasePassword}" ]]; then
  databasePassword="projekte"
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name defined!"
  exit 1
fi

if [[ -z "${remove}" ]]; then
  remove="no"
fi

export MYSQL_PWD="${databasePassword}"

echo "Exporting table headers"
mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --add-drop-table --no-data --skip-triggers "${databaseName}" > "${dumpFile}"

echo "Exporting table data"
# shellcheck disable=SC2086
mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --events --triggers "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' >> "${dumpFile}"

if [[ "${remove}" == "yes" ]]; then
  echo "Dropping database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS \`${databaseName}\`;"
fi

#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -f  File to store the dump in
  -n  Name of database to import to
  -r  Remove the database after download

Example: ${scriptName} -m dev -a -u
EOF
}

trim()
{
  echo -n "$1" | xargs
}

dumpFile=
databaseName=
remove=0

while getopts hf:n:ru? option; do
  case ${option} in
    h) usage; exit 1;;
    f) dumpFile=$(trim "$OPTARG");;
    n) databaseName=$(trim "$OPTARG");;
    r) remove=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${databaseName}" ]]; then
  echo "No database name defined!"
  exit 1
fi

if [[ -z "${dumpFile}" ]]; then
  echo "No dump file defined!"
  exit 1
fi

databaseHostName="35.198.181.44"
databasePort="3306"
databaseUserName="projekte"
databasePassword="projekte"

export MYSQL_PWD="${databasePassword}"

echo "Exporting table headers"
mysqldump -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --add-drop-table --no-data --skip-triggers "${databaseName}" > "${dumpFile}"
echo "Exporting table data"
mysqldump -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --events --triggers "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^ALTER\sDATABASE/d' >> "${dumpFile}"

if [[ "${remove}" == 1 ]]; then
  echo "Dropping database: ${databaseName}"
  mysql -h${databaseHostName} -P${databasePort:-3306} -u${databaseUserName} -e "DROP DATABASE IF EXISTS \`${databaseName}\`;"
fi

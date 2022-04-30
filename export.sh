#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name (i.e. wordpress), default: system
  -u  Upload file to Tofex server

Example: ${scriptName} -m dev -u
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
upload=0

while getopts hs:u? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    u) upload=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "${currentPath}/../env.properties" ]]; then
  echo "No environment specified!"
  exit 1
fi

serverList=( $(ini-parse "${currentPath}/../env.properties" "yes" "${system}" "server") )
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
      databaseHost="localhost"
      echo "--- Dumping database on local server: ${server} ---"
    else
      databaseHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "host")
      echo "--- Dumping database on remote server: ${server} ---"
    fi
    break
  fi
done

if [[ -z "${databaseHost}" ]]; then
  echo "No database settings found"
  exit 1
fi

databasePort=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "port")
databaseUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "user")
databasePassword=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "password")
databaseName=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "name")

if [ -z "${databasePort}" ]; then
  echo "No database port specified!"
  exit 1
fi

if [ -z "${databaseUser}" ]; then
  echo "No database user specified!"
  exit 1
fi

if [ -z "${databasePassword}" ]; then
  echo "No database password specified!"
  exit 1
fi

if [ -z "${databaseName}" ]; then
  echo "No database name specified!"
  exit 1
fi

dumpPath=${currentPath}/dumps

mkdir -p "${dumpPath}"

date=$(date +%Y-%m-%d)
dumpFile=${dumpPath}/mysql-${system}-${date}.sql

rm -rf "${dumpFile}"
touch "${dumpFile}"

export MYSQL_PWD="${databasePassword}"
mysqldump -h"${databaseHost}" -P"${databasePort:-3306}" -u"${databaseUser}" --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --add-drop-table --no-data --skip-triggers "${databaseName}" >>"${dumpFile}"
mysqldump -h"${databaseHost}" -P"${databasePort:-3306}" -u"${databaseUser}" --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --events --routines --triggers "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^ALTER\sDATABASE/d' >>"${dumpFile}"

cd "${dumpPath}"
rm -rf "${dumpFile}.gz"
dumpFileName=$(basename "${dumpFile}")
gzip "${dumpFileName}"

if [[ ${upload} == 1 ]]; then
  "${currentPath}/upload-dump.sh" -s "${system}" -m "${system}" -d "${date}"
fi

#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help    Show this message
  --system  System name (i.e. wordpress), default: system
  --upload  Upload file to Tofex server, default: no

Example: ${scriptName} --upload
EOF
}

system=
upload=

if [[ -f "${currentPath}/../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${upload}" ]]; then
  upload="no"
fi

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

dumpPath="${currentPath}/../var/mysql/dumps"

mkdir -p "${dumpPath}"

date=$(date +%Y-%m-%d)
dumpFile=${dumpPath}/mysql-${system}-${date}.sql

rm -rf "${dumpFile}"
touch "${dumpFile}"

export MYSQL_PWD="${databasePassword}"

echo "Exporting table headers"
mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --add-drop-table --no-data --skip-triggers "${databaseName}" > "${dumpFile}"

echo "Exporting table data"
# shellcheck disable=SC2086
mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --events --routines --triggers "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' >> "${dumpFile}"

cd "${dumpPath}"
rm -rf "${dumpFile}.gz"
dumpFileName=$(basename "${dumpFile}")
gzip "${dumpFileName}"

if [[ ${upload} == 1 ]]; then
  "${currentPath}/upload-dump.sh" --system "${system}" --mode "${system}" --date "${date}"
fi

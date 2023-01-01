#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help              Show this message
  --exportFile        File to export the data to
  --onlyColumns       Flag if only table columns are to be exported (yes/no), default: no
  --onlyRecords       Flag if only records are to be exported (yes/no), default: no
  --compress          Compress the export, default: yes
  --remove            Remove the database after download (yes/no), default: no

Example: ${scriptName} --exportFile export.sql
EOF
}

exportFile=
onlyColumns=
onlyRecords=
compress=
remove=

if [[ -f "${currentPath}/../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${dumpFile}" ]]; then
  if [[ ! -f "${currentPath}/../env.properties" ]]; then
    echo "No environment specified!"
    exit 1
  fi

  systemName=$(ini-parse "${currentPath}/../env.properties" "yes" "system" "name")

  date=$(date +%Y-%m-%d)
  exportFile=${currentPath}/../var/mysql/dumps/${systemName}-${date}.sql
else
  exportFile=$(dirname "${dumpFile}")
fi

if [[ -z "${onlyColumns}" ]]; then
  onlyColumns="no"
fi

if [[ -z "${onlyRecords}" ]]; then
  onlyRecords="no"
fi

if [[ -z "${compress}" ]]; then
  compress="yes"
fi

if [[ -z "${remove}" ]]; then
  remove="no"
fi

"${currentPath}/../core/script/run.sh" "database:single" "${currentPath}/export/database.sh" \
  --exportFile "${exportFile}" \
  --compress "${compress}" \
  --onlyColumns "${onlyColumns}" \
  --onlyRecords "${onlyRecords}" \
  --remove "${remove}"

#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help        Show this message
  --importFile  Import file
  --reset       Drop current database and re-create it (yes/no), default: no
  --tempDir     Path to temp directory, default: /tmp/mysql
  --removeFile  Remove import file after import, default: no

Example: ${scriptName} --importFile import.sql
EOF
}

importFile=
reset=
tempDir=
removeFile=

source "${currentPath}/../core/prepare-parameters.sh"

if [[ -z "${importFile}" ]]; then
  echo "No import file specified!"
  usage
  exit 1
fi

if [[ -z "${reset}" ]]; then
  reset="no"
fi

if [[ -z "${tempDir}" ]]; then
  tempDir="/tmp/mysql"
fi

if [[ -z "${removeFile}" ]]; then
  removeFile="no"
fi

"${currentPath}/../core/script/run.sh" "database:single" "${currentPath}/import/database.sh" \
  --importFile "file:${importFile}" \
  --reset "${reset}" \
  --tempDir "${tempDir}" \
  --removeFile "${removeFile}"

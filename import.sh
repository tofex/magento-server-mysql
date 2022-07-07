#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name, default: system
  -i  Import file
  -t  Path to temp directory, default: /tmp/mysql
  -r  Remove import file after import, default: no

Example: ${scriptName} -i import.sql
EOF
}

trim()
{
  echo -n "$1" | xargs
}

systemName=
importFile=
tempDir=
removeFile=

while getopts hs:i:t:r? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) systemName=$(trim "$OPTARG");;
    i) importFile=$(trim "$OPTARG");;
    t) tempDir=$(trim "$OPTARG");;
    r) removeFile="yes";;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${systemName}" ]]; then
  systemName="system"
fi

if [[ -z "${importFile}" ]]; then
  echo "No import file specified!"
  usage
  exit 1
fi

if [[ -z "${tempDir}" ]]; then
  tempDir="/tmp/mysql"
fi

if [[ -z "${removeFile}" ]]; then
  removeFile="no"
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "${currentPath}/../env.properties" ]]; then
  echo "No environment specified!"
  exit 1
fi

"${currentPath}/../core/script/database/single.sh" "${currentPath}/import/database.sh" \
  -i "file:${importFile}" \
  -d "${tempDir}" \
  -r "${removeFile}"

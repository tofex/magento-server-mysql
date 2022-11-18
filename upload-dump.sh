#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -m  Mode (dev/test/live)
  -d  Date of the file, default: current date

Example: ${scriptName} -m dev -d 2018-06-05
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
date=
mode=

if [[ -f "${currentPath}/../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${mode}" ]]; then
  usage
  exit 1
fi

if [[ -z "${date}" ]]; then
  date=$(date +%Y-%m-%d)
fi

if [ ! -f "${currentPath}/../env.properties" ]; then
  echo "No environment specified!"
  exit 1
fi

projectId=$(ini-parse "${currentPath}/../env.properties" "yes" "${system}" "projectId")

if [ -z "${projectId}" ]; then
  echo "No project id in environment!"
  exit 1
fi

file="${currentPath}/../var/mysql/dumps/mysql-${mode}-${date}.sql.gz"
objectFile="${projectId}-${mode}.sql.gz"

if [ ! -f "${file}" ]; then
  echo "Requested upload file: ${file} does not exist!"
  exit 1
fi

curl=$(which curl)
if [ -z "${curl}" ]; then
  echo "Curl is not available!"
  exit 1
fi

echo "Please specify access token to Google storage, followed by [ENTER]:"
read -r accessToken

curl -X POST \
  -T "${file}" \
  -H "Authorization: Bearer ${accessToken}" \
  -H "Content-Type: application/x-gzip" \
  "https://www.googleapis.com/upload/storage/v1/b/tofex_vm_mysql/o?uploadType=media&name=${objectFile}"

#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name, default: system
  -m  Mode (dev/test/live)
  -a  Anonymizing
  -u  Upload file to Tofex server
  -r  Remove after upload

Example: ${scriptName} -m dev -a -u
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
anonymize=0
mode=
upload=0
remove=0

while getopts hs:am:ur? option; do
  case ${option} in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    a) anonymize=1;;
    m) mode=$(trim "$OPTARG");;
    u) upload=1;;
    r) remove=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${mode}" ]]; then
  usage
  exit 1
fi

if [[ "${mode}" != "dev" ]] && [[ "${mode}" != "test" ]] && [[ "${mode}" != "live" ]]; then
  usage
  exit 1
fi

if [[ "${mode}" == "test" ]]; then
  echo "Test mode forces anonymizing"
  anonymize=1
fi

if [[ "${mode}" == "live" ]]; then
  echo "Live mode prohibits anonymizing"
  anonymize=0
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f ${currentPath}/../env.properties ]]; then
  echo "No environment specified!"
  exit 1
fi

projectId=$(ini-parse "${currentPath}/../env.properties" "yes" "${system}" "projectId")
if [[ -z "${projectId}" ]]; then
  echo "No project id specified!"
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

if [[ "${anonymize}" == 1 ]]; then
    echo "Please specify access token to SQL, followed by [ENTER]:"
    read -r accessToken

    remoteIpAddress="$(dig TXT -4 +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}')"
    echo "Using remote IP address: ${remoteIpAddress}"

    access=$(curl --header "Authorization: Bearer ${accessToken}" -X GET https://www.googleapis.com/sql/v1beta4/projects/optimal-relic-240610/instances/projekte?fields=settings 2>/dev/null | jq .settings.ipConfiguration | grep "${remoteIpAddress}" | wc -l)

    if [[ "${access}" -eq 0 ]]; then
        echo "Granting access of IP address: ${remoteIpAddress} to Cloud SQL"
        settings=$(curl --header "Authorization: Bearer ${accessToken}" -X GET https://www.googleapis.com/sql/v1beta4/projects/optimal-relic-240610/instances/projekte?fields=settings 2>/dev/null | jq .settings.ipConfiguration | jq ".authorizedNetworks[.authorizedNetworks| length] |= . + {\"value\":\"${remoteIpAddress}\",\"name\":\"${projectId}\",\"kind\":\"sql#aclEntry\"}")
        curl --header "Authorization: Bearer ${accessToken}" --header "Content-Type: application/json" --data "{\"settings\":{\"ipConfiguration\":${settings}}}" -X PATCH https://www.googleapis.com/sql/v1beta4/projects/optimal-relic-240610/instances/projekte
    else
        echo "Access of IP address: ${remoteIpAddress} to Cloud SQL already granted"
    fi
fi

echo "Checking for unknown tables"
unknownTables=$("${currentPath}/tables.sh" -i -p -u | wc -l)

if [[ ${unknownTables} -gt 0 ]]; then
  echo "Checking the database has found unknown tables! Please add them to the according Magento module."
  exit 1
fi

echo "Collecting tables to export without data"
excludeTables=( $("${currentPath}/tables.sh" -i -p -e "${mode}") )
echo "Exporting ${#excludeTables[@]} tables without data"

ignore=$(printf " --ignore-table=${databaseName}.%s" "${excludeTables[@]}")
ignore=${ignore:1}

dumpPath="${currentPath}/../var/mysql/dumps"

mkdir -p "${dumpPath}"

date=$(date +%Y-%m-%d)
dumpFile=${dumpPath}/mysql-${mode}-${date}.sql

export MYSQL_PWD="${databasePassword}"
echo "Exporting table headers"
mysqldump -h"${databaseHost}" -P"${databasePort:-3306}" -u"${databaseUser}" --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --add-drop-table --no-data --skip-triggers "${databaseName}" > "${dumpFile}"
echo "Exporting table data"
# shellcheck disable=SC2086
mysqldump -h"${databaseHost}" -P"${databasePort:-3306}" -u"${databaseUser}" --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --events --triggers ${ignore} "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' >> "${dumpFile}"

if [[ "${anonymize}" == "1" ]]; then
  echo "Anonymizing table data"
  tempDatabaseName=$(printf '%s' "${databaseName}-${mode}-${date}" | md5sum | cut -d ' ' -f 1)

  "${currentPath}/upload.sh" -m "${mode}" -d "${date}" -n "${tempDatabaseName}"
  "${currentPath}/anonymize.sh" -n "${tempDatabaseName}"
  "${currentPath}/download.sh" -n "${tempDatabaseName}" -f "${dumpFile}" -r
fi

cd "${dumpPath}"
rm -rf "${dumpFile}.gz"
echo "Creating archive: ${dumpFile}.gz"
gzip "$(basename "${dumpFile}")"

if [[ ${upload} == 1 ]]; then
  echo "Uploading created archive"
  "${currentPath}/upload-dump.sh" -m "${mode}" -d "${date}"

  if [[ "${remove}" == 1 ]]; then
    echo "Removing created archive: ${dumpFile}.gz"
    rm -rf "${dumpFile}.gz"
  fi
fi

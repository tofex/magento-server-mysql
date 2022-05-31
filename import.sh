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

system=
importFile=
removeFile="no"
tempDir=

while getopts hs:i:t:r? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    i) importFile=$(trim "$OPTARG");;
    t) tempDir=$(trim "$OPTARG");;
    r) removeFile="yes";;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${importFile}" ]]; then
  echo "No import file specified!"
  usage
  exit 1
fi

if [[ -z "${tempDir}" ]]; then
  tempDir="/tmp/mysql"
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
databaseServerName=
databaseServerType=
for server in "${serverList[@]}"; do
  database=$(ini-parse "${currentPath}/../env.properties" "no" "${server}" "database")
  if [[ -n "${database}" ]]; then
    serverType=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "type")
    if [[ "${serverType}" == "local" ]]; then
      databaseHost="localhost"
      echo "--- Importing database on local server: ${server} ---"
    else
      databaseHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "host")
      echo "--- Importing database on remote server: ${server} ---"
    fi
    databaseServerName="${server}"
    databaseServerType="${serverType}"
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

if [[ -z "${databasePort}" ]]; then
  echo "No database port specified!"
  exit 1
fi

if [[ -z "${databaseUser}" ]]; then
  echo "No database user specified!"
  exit 1
fi

if [[ -z "${databasePassword}" ]]; then
  echo "No database password specified!"
  exit 1
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name specified!"
  exit 1
fi

if [[ "${databaseServerType}" == "local" ]]; then
  "${currentPath}/import-local.sh" \
    -o "${databaseHost}" \
    -p "${databasePort}" \
    -e "${databaseUser}" \
    -w "${databasePassword}" \
    -b "${databaseName}" \
    -i "${importFile}" \
    -t "${tempDir}" \
    -r "${removeFile}"
elif [[ "${databaseServerType}" == "ssh" ]]; then
  sshUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${databaseServerName}" "user")
  sshHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${databaseServerName}" "host")

  echo "Getting server fingerprint"
  ssh-keyscan "${sshHost}" >> ~/.ssh/known_hosts

  importFileName=$(basename "${importFile}")

  echo "Copying file to ${sshUser}@${databaseHost}:/tmp/${importFileName}"
  scp -q "${importFile}" "${sshUser}@${databaseHost}:/tmp/${importFileName}"
  echo "Copying script to ${sshUser}@${databaseHost}:/tmp/import-local.sh"
  scp -q "${currentPath}/import-local.sh" "${sshUser}@${databaseHost}:/tmp/import-local.sh"

  echo "Executing script at ${sshUser}@${sshHost}:/tmp/import-local.sh"
  ssh "${sshUser}@${databaseHost}" "/tmp/import-local.sh" \
    -o "${databaseHost}" \
    -p "${databasePort}" \
    -e "${databaseUser}" \
    -w "${databasePassword}" \
    -b "${databaseName}" \
    -i "/tmp/${importFileName}" \
    -t "${tempDir}" \
    -r "yes"

  echo "Removing script from: ${sshUser}@${sshHost}:/tmp/import-local.sh"
  ssh "${sshUser}@${databaseHost}" "rm -rf /tmp/import-local.sh"

  if [[ "${removeFile}" == "yes" ]]; then
    echo "Removing import file at: ${importFile}"
    rm -rf "${importFile}"
  fi
else
  echo "Invalid database server type: ${databaseServerType}"
  exit 1
fi

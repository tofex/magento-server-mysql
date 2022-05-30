#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -y  System name, default: system
  -u  Root user, default: root
  -s  Root password
  -e  Name of the database user to create
  -w  Database password of the user to create
  -b  Database name to grant the user rights to
  -g  Grant user super rights
  -c  Create initial database

Example: ${scriptName} -u root -s secret -e user -w password -b dbname -g -c
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
databaseVersion=
databaseRootUser=
databaseRootPassword=
databaseUser=
databasePassword=
databaseName=
grantSuperRights=
createDatabase=

while getopts hy:u:s:e:w:b:gc? option; do
  case "${option}" in
    h) usage; exit 1;;
    y) system=$(trim "$OPTARG");;
    u) databaseRootUser=$(trim "$OPTARG");;
    s) databaseRootPassword=$(trim "$OPTARG");;
    e) databaseUser=$(trim "$OPTARG");;
    w) databasePassword=$(trim "$OPTARG");;
    b) databaseName=$(trim "$OPTARG");;
    g) grantSuperRights="yes";;
    c) createDatabase="yes";;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${databaseRootUser}" ]]; then
  databaseRootUser="root"
fi

if [[ -z "${databaseRootPassword}" ]]; then
  echo "No database root password specified!"
  exit 1
fi

if [[ -z "${grantSuperRights}" ]]; then
  grantSuperRights="no"
fi

if [[ -z "${createDatabase}" ]]; then
  createDatabase="no"
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "${currentPath}/../env.properties" ]]; then
  echo "No environment specified!"
  exit 1
fi

serverList=( $(ini-parse "${currentPath}/../env.properties" "yes" "system" "server") )
if [[ "${#serverList[@]}" -eq 0 ]]; then
  echo "No servers specified!"
  exit 1
fi

database=
databaseHost=
databaseServerType=
databaseServerName=

for server in "${serverList[@]}"; do
  database=$(ini-parse "${currentPath}/../env.properties" "no" "${server}" "database")
  if [[ -n "${database}" ]]; then
    serverType=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "type")
    if [[ "${serverType}" == "local" ]]; then
      echo "--- Creating database user on local server: ${server} ---"
      databaseHost="localhost"
    else
      echo "--- Creating database user on remote server: ${server} ---"
      databaseHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "host")
    fi
    databaseServerType="${serverType}"
    databaseServerName="${server}"
    break
  fi
done

if [[ -z "${databaseHost}" ]]; then
  echo "No database settings found"
  exit 1
fi

databaseType=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "type")
databaseVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "version")
databasePort=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "port")

if [[ -z "${databaseType}" ]]; then
  echo "No database type specified!"
  exit 1
fi

if [[ -z "${databaseVersion}" ]]; then
  echo "No database version specified!"
  exit 1
fi

if [[ -z "${databasePort}" ]]; then
  echo "No database port specified!"
  exit 1
fi

if [[ -z "${databaseUser}" ]]; then
  databaseUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "user")
else
  if [[ -z "${databaseUser}" ]]; then
    echo "No database user specified!"
    exit 1
  fi

  ini-set "${currentPath}/../env.properties" "yes" "${database}" user "${databaseUser}"
fi

if [[ -z "${databasePassword}" ]]; then
  databasePassword=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "password")
else
  if [[ -z "${databasePassword}" ]]; then
    echo "No database password specified!"
    exit 1
  fi

  ini-set "${currentPath}/../env.properties" "yes" "${database}" password "${databasePassword}"
fi

if [[ -z "${databaseName}" ]]; then
  databaseName=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "name")
else
  if [[ -z "${databaseName}" ]]; then
    echo "No database name specified!"
    exit 1
  fi

  ini-set "${currentPath}/../env.properties" "yes" "${database}" name "${databaseName}"
fi

if [[ "${databaseType}" == "mysql" ]] && [[ "${databaseVersion}" == "8.0" ]]; then
  createUserScript="${currentPath}/create-user-local-8.0.sh"
else
  createUserScript="${currentPath}/create-user-local.sh"
fi

if [[ "${databaseServerType}" == "local" ]] || [[ "${databaseServerType}" == "docker" ]]; then
  "${createUserScript}" \
    -v "${databaseVersion}" \
    -s "${databaseRootPassword}" \
    -o "${databaseHost}" \
    -p "${databasePort}" \
    -e "${databaseUser}" \
    -w "${databasePassword}" \
    -b "${databaseName}" \
    -g "${grantSuperRights}" \
    -c "${createDatabase}"
elif [[ "${serverType}" == "ssh" ]]; then
  sshUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${databaseServerName}" "user")
  sshHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${databaseServerName}" "host")

  echo "Getting server fingerprint"
  ssh-keyscan "${sshHost}" >> ~/.ssh/known_hosts

  echo "Copying script to ${sshUser}@${databaseHost}:/tmp/create-user-local.sh"
  scp -q "${createUserScript}" "${sshUser}@${databaseHost}:/tmp/create-user-local.sh"

  echo "Executing script at ${sshUser}@${sshHost}:/tmp/create-user-local.sh"
  ssh "${sshUser}@${databaseHost}" "/tmp/create-user-local.sh"

  echo "Removing script from: ${sshUser}@${sshHost}:/tmp/create-user-local.sh"
  ssh "${sshUser}@${databaseHost}" "rm -rf /tmp/create-user-local.sh"
else
  echo "Invalid database server type: ${serverType}"
  exit 1
fi

#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -y  System name, default: system
  -r  Root user, default: root
  -w  Root password
  -u  Name of the database user to create
  -s  Database password of the user to create
  -b  Database name to grant the user rights to
  -g  Grant user super rights
  -c  Create initial database

Example: ${scriptName} -r root -w secret -u user -s password -b dbname -g -c
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

while getopts hy:r:w:u:s:b:gc? option; do
  case "${option}" in
    h) usage; exit 1;;
    y) system=$(trim "$OPTARG");;
    r) databaseRootUser=$(trim "$OPTARG");;
    w) databaseRootPassword=$(trim "$OPTARG");;
    u) databaseUser=$(trim "$OPTARG");;
    s) databasePassword=$(trim "$OPTARG");;
    b) databaseName=$(trim "$OPTARG");;
    g) grantSuperRights="yes";;
    c) createDatabase="yes";;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${databaseRootUser}" ]] && [[ -f /opt/install/env.properties ]]; then
  databaseRootUser=$(ini-parse "/opt/install/env.properties" "no" "mysql" "rootUser")
fi

if [[ -z "${databaseRootUser}" ]]; then
  databaseRootUser="root"
fi

if [[ -z "${databaseRootPassword}" ]] && [[ -f /opt/install/env.properties ]]; then
  databaseRootPassword=$(ini-parse "/opt/install/env.properties" "no" "mysql" "rootPassword")
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

if [[ -n "${databaseUser}" ]]; then
  "${currentPath}/../env/update-database.sh -u \"${databaseUser}\""
fi

if [[ -n "${databasePassword}" ]]; then
  "${currentPath}/../env/update-database.sh -s \"${databasePassword}\""
fi

if [[ -n "${databaseName}" ]]; then
  "${currentPath}/../env/update-database.sh -d \"${databaseName}\""
fi

database=$("${currentPath}/../core/server/database/single.sh" -s "${system}")

databaseType=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "type")
databaseVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "${database}" "version")

if [[ "${databaseType}" == "mysql" ]] && [[ "${databaseVersion}" == "8.0" ]]; then
  createUserScript="${currentPath}/create-user/database-mysql-8.0.sh"
else
  createUserScript="${currentPath}/create-user/database.sh"
fi

"${currentPath}/../core/script/database/single.sh" "${createUserScript}" \
  -r "${databaseRootUser}" \
  -w "${databaseRootPassword}" \
  -g "${grantSuperRights}" \
  -c "${createDatabase}"

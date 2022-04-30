#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name, default: system
  -m  List only the modules
  -u  Show only unknown attributes

Example: ${scriptName} -m dev
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
installation="install"
showOnlyModules=0
showOnlyUnknownAttributes=0

while getopts hs:i:mu? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    i) installation=$(trim "$OPTARG");;
    m) showOnlyModules=1;;
    u) showOnlyUnknownAttributes=1;;
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
      if [[ "${showOnlyModules}" == 0 ]]; then
        echo "--- Checking database tables on local server: ${server} ---"
      fi
    else
      databaseHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "host")
      if [[ "${showOnlyModules}" == 0 ]]; then
        echo "--- Checking database tables on remote server: ${server} ---"
      fi
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

magentoVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "${installation}" "magentoVersion")
if [[ -z "${magentoVersion}" ]]; then
  echo "No magento version specified!"
  exit 1
fi

cd "${currentPath}/lists/attributes/magento${magentoVersion:0:1}"

modules=( )
unknownAttributes=( )

export MYSQL_PWD="${databasePassword}"

entityTypes=( $(mysql -B -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" --disable-column-names -e "select eav_entity_type.entity_type_code from eav_entity_type order by eav_entity_type.entity_type_code;") )

for entityType in "${entityTypes[@]}"; do
  attributes=( $(mysql -B -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" --disable-column-names -e "select eav_attribute.attribute_code from eav_attribute left join eav_entity_type on eav_entity_type.entity_type_id = eav_attribute.entity_type_id where eav_entity_type.entity_type_code = \"${entityType}\" order by eav_attribute.attribute_code;") )

  for attribute in "${attributes[@]}"; do
    module=$(grep -w -l -r "${entityType}:${attribute}" | cat)

    if [[ -n "${module}" ]]; then
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownAttributes}" == 0 ]]; then
        echo "${entityType}:${attribute}: ${module}"
      fi
      modules+=( "${module}" )
    else
      if [[ -f "${currentPath}/project.attributes.list" ]] && [[ $(grep -cFx "${entityType}:${attribute}" "${currentPath}/project.attributes.list" | cat) == 1 ]]; then
        echo "${entityType}:${attribute}: Project"
      else
        unknownAttributes+=( "${entityType}:${attribute}" )
      fi
    fi
  done
done

if [[ "${showOnlyModules}" == 0 ]] && [[ "${#unknownAttributes[@]}" -gt 0 ]]; then
  if [[ "${showOnlyUnknownAttributes}" == 0 ]]; then
    echo ""
    echo "--- Unknown attributes ---"
  fi
  for attribute in "${unknownAttributes[@]}"; do
    echo "${attribute}"
  done
fi

if [[ "${showOnlyModules}" == 1 ]]; then
  modules=( $(echo "${modules[@]}" | tr ' ' '\n' | sort -u) )
  for module in "${modules[@]}"; do
    echo "${module}"
  done
fi

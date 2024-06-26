#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name, default: system
  -e  List tables to exclude (cms/dev/test/live)
  -d  List tables to include (cms/dev/test/live)
  -i  Use ignore list if available
  -p  Use project list if available
  -m  List only the modules
  -u  Show only unknown tables
  -c  Show only unknown columns

Example: ${scriptName} -m dev
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
installation="install"
exclude=
include=
useIgnoreList=0
useProjectList=0
showOnlyModules=0
showOnlyUnknownTables=0
showOnlyUnknownColumns=0

while getopts hs:l:e:d:ipmuc? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    l) installation=$(trim "$OPTARG");;
    e) exclude=$(trim "$OPTARG");;
    d) include=$(trim "$OPTARG");;
    i) useIgnoreList=1;;
    p) useProjectList=1;;
    m) showOnlyModules=1;;
    u) showOnlyUnknownTables=1;;
    c) showOnlyUnknownColumns=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -n "${exclude}" ]] && [[ "${exclude}" != "cms" ]] && [[ "${exclude}" != "dev" ]] && [[ "${exclude}" != "test" ]] && [[ "${exclude}" != "live" ]]; then
  usage
  exit 1
fi

if [[ -n "${include}" ]] && [[ "${include}" != "cms" ]] && [[ "${include}" != "dev" ]] && [[ "${include}" != "test" ]] && [[ "${include}" != "live" ]]; then
  usage
  exit 1
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
      databaseHost="127.0.0.1"
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
        echo "--- Checking database tables on local server: ${server} ---"
      fi
    else
      databaseHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "host")
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
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

if [[ "${databaseHost}" == "localhost" ]]; then
  databaseHost="127.0.0.1"
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

cd "${currentPath}/lists/tables/magento${magentoVersion:0:1}"

cmsList=( $(grep -roE "(.*):cms$" . | cut -c 3-) )
knownCmsTables=( )
for cmsListEntry in "${cmsList[@]}"; do
  knownCmsTables+=( "${cmsListEntry}" )
done

devList=( $(grep -roE "(.*):dev$" . | cut -c 3-) )
knownDevTables=( )
for devListEntry in "${devList[@]}"; do
  knownDevTables+=( "${devListEntry}" )
done

testList=( $(grep -roE "(.*):test$" . | cut -c 3-) )
knownTestTables=( )
for testListEntry in "${testList[@]}"; do
  knownTestTables+=( "${testListEntry}" )
done

liveList=( $(grep -roE "(.*):live$" . | cut -c 3-) )
knownLiveTables=( )
for liveListEntry in "${liveList[@]}"; do
  knownLiveTables+=( "${liveListEntry}" )
done

ignoreTables=( )
if [[ "${useIgnoreList}" == 1 ]] && [[ -f "${currentPath}/../var/mysql/ignore.list" ]]; then
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ -n $(trim "${line}") ]]; then
      ignoreTables+=( "${line}" )
    fi
  done < "${currentPath}/../var/mysql/ignore.list"
fi

if [[ "${useProjectList}" == 1 ]] && [[ -f "${currentPath}/../var/mysql/project.list" ]]; then
  cmsList=( $(grep -oE "(.*):cms$" "${currentPath}/../var/mysql/project.list" | cat) )
  for cmsListEntry in "${cmsList[@]}"; do
    knownCmsTables+=( "Project:${cmsListEntry}" )
  done

  devList=( $(grep -oE "(.*):dev$" "${currentPath}/../var/mysql/project.list" | cat) )
  for devListEntry in "${devList[@]}"; do
    knownDevTables+=( "Project:${devListEntry}" )
  done

  testList=( $(grep -oE "(.*):test$" "${currentPath}/../var/mysql/project.list" | cat) )
  for testListEntry in "${testList[@]}"; do
    knownTestTables+=( "Project:${testListEntry}" )
  done

  liveList=( $(grep -oE "(.*):live$" "${currentPath}/../var/mysql/project.list" | cat) )
  for liveListEntry in "${liveList[@]}"; do
    knownLiveTables+=( "Project:${liveListEntry}" )
  done
fi

export MYSQL_PWD="${databasePassword}"
allTables=( $(mysql -B -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" --disable-column-names -e "show full tables where Table_Type != 'VIEW';" | awk '{print $1;}') )

knownTables=( )
unknownTables=( )
modules=( )
for table in "${allTables[@]}"; do
  for knownCmsTable in "${knownCmsTables[@]}"; do
    IFS=':' read -r -a knownCmsTableData <<< "${knownCmsTable}"
    if [[ "${table}" == "${knownCmsTableData[1]}" ]]; then
      modules+=( "${knownCmsTableData[0]}" )
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
        echo "${table}: ${knownCmsTableData[0]}"
      elif [[ "${include}" == "cms" ]]; then
        echo "${table}"
      fi
      knownTables+=( "${table}" )
      continue 2;
    fi
    # shellcheck disable=SC2076,SC2049
    if [[ "${knownCmsTableData[1]}" =~ "*" ]]; then
      pattern=$(echo "${knownCmsTableData[1]}" | sed 's/*/.*/')
      # shellcheck disable=SC2003
      if [[ $(expr match "${table}" "${pattern}") -eq "${#table}" ]]; then
        modules+=( "${knownCmsTableData[0]}" )
        if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
          echo "${table}: ${knownCmsTableData[0]}"
        elif [[ "${include}" == "cms" ]]; then
          echo "${table}"
        fi
        knownTables+=( "${table}" )
        continue 2;
      fi
    fi
  done
  for knownDevTable in "${knownDevTables[@]}"; do
    IFS=':' read -r -a knownDevTableData <<< "${knownDevTable}"
    if [[ "${table}" == "${knownDevTableData[1]}" ]]; then
      modules+=( "${knownDevTableData[0]}" )
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
        echo "${table}: ${knownDevTableData[0]}"
      elif [[ "${exclude}" == "cms" ]] || [[ "${include}" == "dev" ]]; then
        echo "${table}"
      fi
      knownTables+=( "${table}" )
      continue 2;
    fi
    # shellcheck disable=SC2076,SC2049
    if [[ "${knownDevTableData[1]}" =~ "*" ]]; then
      pattern=$(echo "${knownDevTableData[1]}" | sed 's/*/.*/')
      # shellcheck disable=SC2003
      if [[ $(expr match "${table}" "${pattern}") -eq "${#table}" ]]; then
        modules+=( "${knownDevTableData[0]}" )
        if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
          echo "${table}: ${knownDevTableData[0]}"
        elif [[ "${exclude}" == "cms" ]] || [[ "${include}" == "dev" ]]; then
          echo "${table}"
        fi
        knownTables+=( "${table}" )
        continue 2;
      fi
    fi
  done
  for knownTestTable in "${knownTestTables[@]}"; do
    IFS=':' read -r -a knownTestTableData <<< "${knownTestTable}"
    if [[ "${table}" == "${knownTestTableData[1]}" ]]; then
      modules+=( "${knownTestTableData[0]}" )
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
        echo "${table}: ${knownTestTableData[0]}"
      elif [[ "${exclude}" == "cms" ]] || [[ "${exclude}" == "dev" ]] || [[ "${include}" == "test" ]]; then
        echo "${table}"
      fi
      knownTables+=( "${table}" )
      continue 2;
    fi
    # shellcheck disable=SC2076,SC2049
    if [[ "${knownTestTableData[1]}" =~ "*" ]]; then
      pattern=$(echo "${knownTestTableData[1]}" | sed 's/*/.*/')
      # shellcheck disable=SC2003
      if [[ $(expr match "${table}" "${pattern}") -eq "${#table}" ]]; then
        modules+=( "${knownTestTableData[0]}" )
        if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
          echo "${table}: ${knownTestTableData[0]}"
        elif [[ "${exclude}" == "cms" ]] || [[ "${exclude}" == "dev" ]] || [[ "${include}" == "test" ]]; then
          echo "${table}"
        fi
        knownTables+=( "${table}" )
        continue 2;
      fi
    fi
  done
  for knownLiveTable in "${knownLiveTables[@]}"; do
    IFS=':' read -r -a knownLiveTableData <<< "${knownLiveTable}"
    if [[ "${table}" == "${knownLiveTableData[1]}" ]]; then
      modules+=( "${knownLiveTableData[0]}" )
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
        echo "${table}: ${knownLiveTableData[0]}"
      elif [[ "${exclude}" == "cms" ]] || [[ "${exclude}" == "dev" ]] || [[ "${exclude}" == "test" ]] || [[ "${include}" == "live" ]]; then
        echo "${table}"
      fi
      knownTables+=( "${table}" )
      continue 2;
    fi
    # shellcheck disable=SC2076,SC2049
    if [[ "${knownLiveTableData[1]}" =~ "*" ]]; then
      pattern=$(echo "${knownLiveTableData[1]}" | sed 's/*/.*/')
      # shellcheck disable=SC2003
      if [[ $(expr match "${table}" "${pattern}") -eq "${#table}" ]]; then
        modules+=( "${knownLiveTableData[0]}" )
        if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
          echo "${table}: ${knownLiveTableData[0]}"
        elif [[ "${exclude}" == " cms" ]] || [[ "${exclude}" == "dev" ]] || [[ "${exclude}" == "test" ]] || [[ "${include}" == "live" ]]; then
          echo "${table}"
        fi
        knownTables+=( "${table}" )
        continue 2;
      fi
    fi
  done
  for ingoreTable in "${ignoreTables[@]}"; do
    if [[ "${table}" == "${ingoreTable}" ]]; then
      if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
        echo "${table}: Ignore"
      elif [[ -n "${exclude}" ]]; then
        echo "${table}"
      fi
      continue 2;
    fi
    # shellcheck disable=SC2076,SC2049
    if [[ "${ingoreTable}" =~ "*" ]]; then
      pattern=$(echo "${ingoreTable}" | sed 's/*/.*/')
      # shellcheck disable=SC2003
      if [[ $(expr match "${table}" "${pattern}") -eq "${#table}" ]]; then
        if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
          echo "${table}: Ignore"
        elif [[ -n "${exclude}" ]]; then
          echo "${table}"
        fi
        continue 2;
      fi
    fi
  done
  unknownTables+=( "${table}" )
done

cd "${currentPath}/lists/columns/magento${magentoVersion:0:1}"

unknownColumns=( )

if [[ -z "${exclude}" ]] && [[ -z "${include}" ]] && [[ "${#knownTables[@]}" -gt 0 ]]; then
  for table in "${knownTables[@]}"; do
    allColumns=( $(mysql -B -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" --disable-column-names -e "select column_name from information_schema.columns where table_schema = \"${databaseName}\" and table_name=\"${table}\" order by column_name;") )
    for column in "${allColumns[@]}"; do
      if [[ "${table}" =~ ^amasty_xsearch_category_fulltext_scope[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^catalog_category_flat_store_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^catalog_category_product_index_store[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^catalogrule_product__temp[a-z0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^catalogsearch_fulltext_scope[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^catalog_product_flat_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^inventory_stock_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^sequence_creditmemo_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^sequence_invoice_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^sequence_order_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^sequence_quote_extension_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^sequence_rma_item_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^sequence_cpe3cw_trx_[0-9]+ ]]; then
        continue
      elif [[ "${table}" =~ ^sequence_shipment_[0-9]+ ]]; then
        continue
      else
        module=$(grep -w -l -r '.' -e "${table}:${column}" | cat | cut -c 3-)
      fi
      if [[ -n "${module}" ]]; then
        if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]]; then
          echo "${table}:${column}: ${module}"
        fi
        modules+=( "${module}" )
      else
        if [[ "${useProjectList}" == 1 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -f "${currentPath}/../var/mysql/project.columns.list" ]]; then
          if [[ $(grep -w "${table}:${column}" "${currentPath}/../var/mysql/project.columns.list" | wc -l) -gt 0 ]]; then
            module="Project"
          fi
        fi
        if [[ -z "${module}" ]]; then
          if [[ "${useIgnoreList}" == 1 ]] && [[ -f "${currentPath}/../var/mysql/ignore.columns.list" ]]; then
            if [[ $(grep -w "${table}:${column}" "${currentPath}/../var/mysql/ignore.columns.list" | wc -l) -gt 0 ]]; then
              module="Project"
            fi
          fi
        fi
      fi
      if [[ -z "${module}" ]]; then
        unknownColumns+=( "${table}:${column}" )
      fi
    done
  done
fi

if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownColumns}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]] && [[ "${#unknownTables[@]}" -gt 0 ]]; then
  if [[ "${showOnlyUnknownTables}" == 0 ]]; then
    echo ""
    echo "--- Unknown tables ---"
  fi
  for table in "${unknownTables[@]}"; do
    echo "${table}"
  done
fi

if [[ "${showOnlyModules}" == 0 ]] && [[ "${showOnlyUnknownTables}" == 0 ]] && [[ -z "${exclude}" ]] && [[ -z "${include}" ]] && [[ "${#unknownColumns[@]}" -gt 0 ]]; then
  if [[ "${showOnlyUnknownColumns}" == 0 ]]; then
    echo ""
    echo "--- Unknown columns ---"
  fi
  for column in "${unknownColumns[@]}"; do
    echo "${column}"
  done
fi

if [[ "${showOnlyModules}" == 1 ]]; then
  modules=( $(echo "${modules[@]}" | tr ' ' '\n' | sort -u) )
  for module in "${modules[@]}"; do
    echo "${module}"
  done
fi

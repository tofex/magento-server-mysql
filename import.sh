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
  -t  Path to temp directory
  -r  Remove import file after import, default: no

Example: ${scriptName} -i import.sql
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system="system"
importFile=
removeFile=0
tempDir=

while getopts hs:i:t:r? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    i) importFile=$(trim "$OPTARG");;
    t) tempDir=$(trim "$OPTARG");;
    r) removeFile=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  usage
  exit 1
fi

if [[ -z "${importFile}" ]]; then
  usage
  exit 1
fi

if [[ -z "${tempDir}" ]]; then
  tempDir="/tmp/mysql"
fi

if [[ ! -d "${tempDir}" ]]; then
  rm -rf "${tempDir}"

  echo "Creating temp directory at: ${tempDir}"
  mkdir -p "${tempDir}"
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
      echo "--- Importing database on local server: ${server} ---"
    else
      databaseHost=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "host")
      echo "--- Importing database on remote server: ${server} ---"
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

tempImportFile="${tempDir}"/$(basename "${importFile}")

echo "Copying import file from: ${importFile} to: ${tempImportFile}"
cp "${importFile}" "${tempImportFile}"

echo "Preparing import file at: ${tempDir}/import.sql"
if [[ "${tempImportFile: -7}" == ".tar.gz" ]]; then
  tar -xOzf "${tempImportFile}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^DROP\sDATABASE/d' | sed -e '/^USE\s/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' > "${tempDir}/import.sql"
elif [[ "${tempImportFile: -7}" == ".sql.gz" ]]; then
  cat "${tempImportFile}" | gzip -d -q | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^DROP\sDATABASE/d' | sed -e '/^USE\s/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' > "${tempDir}/import.sql"
elif [[ "${tempImportFile: -4}" == ".zip" ]]; then
  unzip -p "${tempImportFile}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^DROP\sDATABASE/d' | sed -e '/^USE\s/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' > "${tempDir}/import.sql"
elif [[ "${tempImportFile: -4}" == ".sql" ]]; then
  cat "${tempImportFile}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^DROP\sDATABASE/d' | sed -e '/^USE\s/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' > "${tempDir}/import.sql"
else
  echo "Unsupported file format"
  exit 1
fi

echo "Removing import file at: ${tempImportFile}"
rm -rf "${tempImportFile}"

export MYSQL_PWD="${databasePassword}"

echo "Importing dump from file: ${tempDir}/import.sql"
mysql "-h${databaseHost}" "-P${databasePort:-3306}" "-u${databaseUser}" --init-command="SET SESSION FOREIGN_KEY_CHECKS=0;" "${databaseName}" < "${tempDir}/import.sql"

echo "Removing prepared import file at: ${tempDir}/import.sql"
rm -rf "${tempDir}/import.sql"

if [[ "${removeFile}" == 1 ]]; then
  echo "Removing import file at: ${importFile}"
  rm -rf "${importFile}"
fi

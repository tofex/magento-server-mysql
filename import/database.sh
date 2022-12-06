#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help              Show this message
  --databaseHost      Database host, default: 127.0.0.1
  --databasePort      Database port, default: 3306
  --databaseUser      Name of the database user
  --databasePassword  Password of the database user
  --databaseName      Name of the database to import into
  --importFile        Import file
  --tempDir           Path to temp directory, default: /tmp/mysql
  --removeFile        Remove import file after import, default: no

Example: ${scriptName} -u magento -s magento -b magento --importFile import.sql
EOF
}

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
importFile=
tempDir=
removeFile=

if [[ -f "${currentPath}/../../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${databaseHost}" ]] || [[ "${databaseHost}" == "localhost" ]]; then
  databaseHost="127.0.0.1"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseUser}" ]]; then
  echo "No database user specified!"
  usage
  exit 1
fi

if [[ -z "${databasePassword}" ]]; then
  echo "No database password specified!"
  usage
  exit 1
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name specified!"
  usage
  exit 1
fi

if [[ -z "${importFile}" ]]; then
  echo "No import file specified!"
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

if [[ -z "${removeFile}" ]]; then
  removeFile="no"
fi

tempImportFile="${tempDir}"/$(basename "${importFile}")

copied=0
if [[ "${importFile}" != "${tempImportFile}" ]]; then
  echo "Copying import file from: ${importFile} to: ${tempImportFile}"
  cp "${importFile}" "${tempImportFile}"
  copied=1
fi

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

if [[ "${copied}" == 1 ]]; then
  echo "Removing import file at: ${tempImportFile}"
  rm -rf "${tempImportFile}"
fi

export MYSQL_PWD="${databasePassword}"

echo "Importing dump from file: ${tempDir}/import.sql"
mysql "-h${databaseHost}" "-P${databasePort:-3306}" "-u${databaseUser}" --init-command="SET SESSION FOREIGN_KEY_CHECKS=0;" "${databaseName}" < "${tempDir}/import.sql"

echo "Removing prepared import file at: ${tempDir}/import.sql"
rm -rf "${tempDir}/import.sql"

if [[ "${removeFile}" == "yes" ]]; then
  echo "Removing import file at: ${importFile}"
  rm -rf "${importFile}"
fi

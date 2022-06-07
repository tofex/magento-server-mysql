#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -o  Database host, default: localhost
  -p  Database port, default: 3306
  -u  Name of the database user
  -s  Password of the database user
  -b  Name of the database to import into
  -i  Import file
  -d  Path to temp directory, default: /tmp/mysql
  -r  Remove import file after import, default: no

Example: ${scriptName} -i import.sql
EOF
}

trim()
{
  echo -n "$1" | xargs
}

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
importFile=
tempDir=
removeFile=

while getopts ho:p:u:s:b:t:v:i:d:r? option; do
  case "${option}" in
    h) usage; exit 1;;
    o) databaseHost=$(trim "$OPTARG");;
    p) databasePort=$(trim "$OPTARG");;
    u) databaseUser=$(trim "$OPTARG");;
    s) databasePassword=$(trim "$OPTARG");;
    b) databaseName=$(trim "$OPTARG");;
    t) ;;
    v) ;;
    i) importFile=$(trim "$OPTARG");;
    d) tempDir=$(trim "$OPTARG");;
    r) removeFile=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${databaseHost}" ]]; then
  databaseHost="localhost"
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

if [[ "${removeFile}" == "yes" ]]; then
  echo "Removing import file at: ${importFile}"
  rm -rf "${importFile}"
fi

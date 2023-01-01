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
  --exportFile        File to export the data to
  --onlyColumns       Flag if only table columns are to be exported (yes/no), default: no
  --onlyRecords       Flag if only records are to be exported (yes/no), default: no
  --compress          Compress the export (yes/no), default: yes
  --remove            Remove the database after download (yes/no), default: no

Example: ${scriptName} --databaseUser magento --databasePassword magento --databaseName magento --exportFile export.sql
EOF
}

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
exportFile=
onlyColumns=
onlyRecords=
compress=
remove=

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

if [[ -z "${exportFile}" ]]; then
  echo "No export file specified!"
  usage
  exit 1
fi

if [[ -z "${onlyColumns}" ]]; then
  onlyColumns="no"
fi

if [[ -z "${onlyRecords}" ]]; then
  onlyRecords="no"
fi

if [[ -z "${compress}" ]]; then
  compress="yes"
fi

if [[ -z "${remove}" ]]; then
  remove="no"
fi

export MYSQL_PWD="${databasePassword}"

if [[ "${onlyRecords}" == "no" ]]; then
  echo "Exporting all table columns"
  mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --add-drop-table --no-data --skip-triggers "${databaseName}" > "${exportFile}"
fi

if [[ "${onlyColumns}" == "no" ]]; then
  echo "Exporting all table records"
  # shellcheck disable=SC2086
  mysqldump -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --no-tablespaces --no-create-db --lock-tables=false --disable-keys --default-character-set=utf8 --skip-add-drop-table --no-create-info --max_allowed_packet=2G --events --routines --triggers "${databaseName}" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e 's/DEFINER[ ]*=[^@]*@[^ ]*//' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' >> "${exportFile}"
fi

if [[ "${compress}" == "yes" ]]; then
  exportFilePath=$(dirname "${exportFile}")
  mkdir -p "${exportFilePath}"
  cd "${exportFilePath}"

  rm -rf "${exportFile}.gz"
  exportFileName=$(basename "${exportFile}")
  gzip "${exportFileName}"
fi

if [[ "${remove}" == "yes" ]]; then
  echo "Dropping database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS \`${databaseName}\`;"
fi

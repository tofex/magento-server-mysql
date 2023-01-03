#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help                        Show this message
  --databaseHost                Database host, default: 127.0.0.1
  --databasePort                Database port, default: 3306
  --databaseUser                Name of the database user
  --databasePassword            Password of the database user
  --databaseName                Name of the database to import into
  --anonymizeProcedureFileName  Name of the file which contains the procedure to anonymize data

Example: ${scriptName} --databaseUser magento --databasePassword magento --databaseName magento --anonymizeProcedureFileName anonymize.sql
EOF
}

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
anonymizeProcedureFileName=

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

if [[ -z "${anonymizeProcedureFileName}" ]]; then
  echo "No anonymize procedure file name specified!"
  usage
  exit 1
fi

if [[ ! -f "${anonymizeProcedureFileName}" ]]; then
  echo "Anonymize procedure file name not found at: ${anonymizeProcedureFileName}"
  usage
  exit 1
fi

export MYSQL_PWD="${databasePassword}"

if [[ $(mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -s -N -e "SHOW PROCEDURE STATUS WHERE NAME = 'anonymizeMagento';" | wc -l) -eq 1 ]]; then
  echo "Dropping stored procedure"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -e "DROP PROCEDURE anonymizeMagento;"
fi

echo "Adding stored procedure"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" < "${anonymizeProcedureFileName}"

echo "Calling stored procedure"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -e "CALL anonymizeMagento('${databaseName}');"

echo "Dropping stored procedure"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -e "DROP PROCEDURE anonymizeMagento;"

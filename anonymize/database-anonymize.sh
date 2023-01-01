#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help                       Show this message
  --databaseAnonymizeHost      Database host, default: 127.0.0.1
  --databaseAnonymizePort      Database port, default: 3306
  --databaseAnonymizeUser      Name of the database user
  --databaseAnonymizePassword  Password of the database user
  --databaseAnonymizeName      Name of the database to import into

Example: ${scriptName} --databaseAnonymizeUser magento --databaseAnonymizePassword magento --databaseAnonymizeName magento
EOF
}

databaseAnonymizeHost=
databaseAnonymizePort=
databaseAnonymizeUser=
databaseAnonymizePassword=
databaseAnonymizeName=

if [[ -f "${currentPath}/../../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${databaseAnonymizeHost}" ]] || [[ "${databaseAnonymizeHost}" == "localhost" ]]; then
  databaseAnonymizeHost="127.0.0.1"
fi

if [[ -z "${databaseAnonymizePort}" ]]; then
  databaseAnonymizePort="3306"
fi

if [[ -z "${databaseAnonymizeUser}" ]]; then
  echo "No database user specified!"
  usage
  exit 1
fi

if [[ -z "${databaseAnonymizePassword}" ]]; then
  echo "No database password specified!"
  usage
  exit 1
fi

if [[ -z "${databaseAnonymizeName}" ]]; then
  echo "No database name specified!"
  usage
  exit 1
fi

export MYSQL_PWD="${databaseAnonymizePassword}"

if [[ $(mysql -h"${databaseAnonymizeHost}" -P"${databaseAnonymizePort}" -u"${databaseAnonymizeUser}" "${databaseAnonymizeName}" -s -N -e "SHOW PROCEDURE STATUS WHERE NAME = 'anonymizeMagento';" | wc -l) -eq 1 ]]; then
  echo "Dropping stored procedure"
  mysql -h"${databaseAnonymizeHost}" -P"${databaseAnonymizePort}" -u"${databaseAnonymizeUser}" "${databaseAnonymizeName}" -e "DROP PROCEDURE anonymizeMagento;"
fi

echo "Adding stored procedure"
mysql -h"${databaseAnonymizeHost}" -P"${databaseAnonymizePort}" -u"${databaseAnonymizeUser}" "${databaseAnonymizeName}" < "${currentPath}/anonymize.sql"

echo "Calling stored procedure"
mysql -h"${databaseAnonymizeHost}" -P"${databaseAnonymizePort}" -u"${databaseAnonymizeUser}" "${databaseAnonymizeName}" -e "CALL anonymizeMagento('${databaseAnonymizeName}');"

echo "Dropping stored procedure"
mysql -h"${databaseAnonymizeHost}" -P"${databaseAnonymizePort}" -u"${databaseAnonymizeUser}" "${databaseAnonymizeName}" -e "DROP PROCEDURE anonymizeMagento;"

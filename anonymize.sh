#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help              Show this message
  --databaseHost      Host name of database, default: 35.198.181.44
  --databasePort      Port of database, default: 3306
  --databaseUser      User name of database, default: projekte
  --databasePassword  Password of database, default: projekte
  --databaseName      Name of database to anonymize

Example: ${scriptName} --databaseName magento
EOF
}

databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=

if [[ -f "${currentPath}/../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${databaseHost}" ]]; then
  databaseHost="35.198.181.44"
fi

if [[ "${databaseHost}" == "localhost" ]]; then
  databaseHost="127.0.0.1"
fi

if [[ -z "${databasePort}" ]]; then
  databasePort="3306"
fi

if [[ -z "${databaseUser}" ]]; then
  databaseUser="projekte"
fi

if [[ -z "${databasePassword}" ]]; then
  databasePassword="projekte"
fi

if [[ -z "${databaseName}" ]]; then
  echo "No database name defined!"
  exit 1
fi

export MYSQL_PWD="${databasePassword}"

if [[ $(mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -s -N -e "SHOW PROCEDURE STATUS WHERE NAME = 'anonymizeMagento';" | wc -l) -eq 1 ]]; then
  echo "Dropping stored procedure"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -e "DROP PROCEDURE anonymizeMagento;"
fi

echo "Adding stored procedure"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" < "${currentPath}/anonymize.sql"

echo "Calling stored procedure"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -e "CALL anonymizeMagento('${databaseName}');"

echo "Dropping stored procedure"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" "${databaseName}" -e "DROP PROCEDURE anonymizeMagento;"

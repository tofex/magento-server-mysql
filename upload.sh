#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help              Show this message
  --mode              Mode (dev/test/live)
  --date              Date of the file, default: current date
  --databaseHost      Host name of database, default: 35.198.181.44
  --databasePort      Port of database, default: 3306
  --databaseUser      User name of database, default: projekte
  --databasePassword  Password of database, default: projekte
  --databaseName      Name of database to import to
  --reset             Drop current database and re-create it (yes/no), default: no

Example: ${scriptName} --mode dev --date 2018-06-05 --databaseName magento
EOF
}

mode=
date=
databaseHost=
databasePort=
databaseUser=
databasePassword=
databaseName=
reset=

if [[ -f "${currentPath}/../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${mode}" ]]; then
  echo "No mode defined!"
  exit 1
fi

if [[ -z "${date}" ]]; then
  date=$(date +%Y-%m-%d)
fi

if [[ -z "${databaseHost}" ]]; then
  databaseHost="35.198.181.44"
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

if [[ -z "${reset}" ]]; then
  reset="no"
fi

dumpPath="${currentPath}/../var/mysql/dumps"

importSourceName="mysql-${mode}-${date}"

deleteExtracted=0

if [[ ! -f "${dumpPath}/${importSourceName}.sql" ]]; then
  if [[ -f "${dumpPath}/${importSourceName}.tar.gz" ]]; then
    echo "Extracting file at: ${dumpPath}/${importSourceName}.sql from: ${dumpPath}/${importSourceName}.tar.gz"
    tar -xOzf "${dumpPath}/${importSourceName}.tar.gz" > "${dumpPath}/${importSourceName}.sql"
    deleteExtracted=1
  elif [[ -f "${dumpPath}/${importSourceName}.sql.gz" ]]; then
    echo "Extracting file at: ${dumpPath}/${importSourceName}.sql from: ${dumpPath}/${importSourceName}.sql.gz"
    cat "${dumpPath}/${importSourceName}.sql.gz" | gzip -d -q > "${dumpPath}/${importSourceName}.sql"
    deleteExtracted=1
  elif [[ -f "${dumpPath}/${importSourceName}.zip" ]]; then
    echo "Extracting file at: ${dumpPath}/${importSourceName}.sql from: ${dumpPath}/${importSourceName}.zip"
    deleteExtracted=1
    unzip -p "${dumpPath}/${importSourceName}.zip" > "${dumpPath}/${importSourceName}.sql"
  fi
fi

if [[ ! -f "${dumpPath}/${importSourceName}.sql" ]]; then
  echo "Invalid import source: ${dumpPath}/${importSourceName}.sql!"
  exit 1
fi

cd "${dumpPath}"

echo "Preparing upload at: ${dumpPath}/upload.sql"
cat "${importSourceName}.sql" | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | sed -e '/^CREATE\sDATABASE/d' | sed -e '/^DROP\sDATABASE/d' | sed -e '/^USE\s/d' | sed -e '/^ALTER\sDATABASE/d' | sed -e 's/ROW_FORMAT=FIXED//g' > upload.sql

export MYSQL_PWD="${databasePassword}"

if [[ "${reset}" == "yes" ]]; then
  echo "Dropping database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "DROP DATABASE IF EXISTS \`${databaseName}\`;"

  echo "Creating database: ${databaseName}"
  mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" -e "CREATE DATABASE \`${databaseName}\` CHARACTER SET utf8 COLLATE utf8_general_ci;";
fi

echo "Uploading to database: ${databaseName}"
mysql -h"${databaseHost}" -P"${databasePort}" -u"${databaseUser}" --init-command="SET SESSION FOREIGN_KEY_CHECKS=0;" "${databaseName}" < upload.sql

if [[ "${deleteExtracted}" == 1 ]]; then
  echo "Removing extracted file at: ${dumpPath}/${importSourceName}.sql"
  rm -rf "${dumpPath}/${importSourceName}.sql"
fi

echo "Removing prepared upload at: ${dumpPath}/upload.sql"
rm -rf upload.sql

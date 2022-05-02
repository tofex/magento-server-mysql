#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f ${currentPath}/../env.properties ]]; then
    echo "No environment specified!"
    exit 1
fi

mkdir -p "${currentPath}/../var/mysql"

echo "Writing all unknown tables into: ${currentPath}/../var/mysql/project.list"
unknownTables=( $("${currentPath}/tables.sh" -i -u) )
rm -rf "${currentPath}/../var/mysql/project.list"
touch "${currentPath}/../var/mysql/project.list"
for unknownTable in "${unknownTables[@]}"; do
  echo "${unknownTable}:dev" >> "${currentPath}/../var/mysql/project.list"
done

echo "Writing all unknown columns into: ${currentPath}/../var/mysql/project.columns.list"
"${currentPath}/tables.sh" -i -c > "${currentPath}/../var/mysql/project.columns.list"

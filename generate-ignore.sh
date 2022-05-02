#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f ${currentPath}/../env.properties ]]; then
    echo "No environment specified!"
    exit 1
fi

mkdir -p "${currentPath}/../var/mysql/ignore.list"

echo "Writing all unknown tables into: ${currentPath}/../var/mysql/ignore.list"
"${currentPath}/tables.sh" -p -u > "${currentPath}/../var/mysql/ignore.list"

echo "Writing all unknown columns into: ${currentPath}/../var/mysql/ignore.columns.list"
"${currentPath}/tables.sh" -p -c > "${currentPath}/../var/mysql/ignore.columns.list"

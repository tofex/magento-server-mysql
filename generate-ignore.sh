#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f ${currentPath}/../env.properties ]]; then
    echo "No environment specified!"
    exit 1
fi

echo "Writing all unknown tables into: ${currentPath}/ignore.list"
"${currentPath}/tables.sh" -p -u > "${currentPath}/ignore.list"

echo "Writing all unknown columns into: ${currentPath}/ignore.columns.list"
"${currentPath}/tables.sh" -p -c > "${currentPath}/ignore.columns.list"

#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f ${currentPath}/../env.properties ]]; then
    echo "No environment specified!"
    exit 1
fi

echo "Writing all unknown tables into: ${currentPath}/project.list"
unknownTables=( $("${currentPath}/tables.sh" -i -u) )
rm -rf "${currentPath}/project.list"
touch "${currentPath}/project.list"
for unknownTable in "${unknownTables[@]}"; do
  echo "${unknownTable}:dev" >> "${currentPath}/project.list"
done

echo "Writing all unknown columns into: ${currentPath}/project.columns.list"
"${currentPath}/tables.sh" -i -c > "${currentPath}/project.columns.list"

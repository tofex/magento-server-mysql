#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help  Show this message

Example: ${scriptName}
EOF
}

source "${currentPath}/../core/prepare-parameters.sh"

"${currentPath}/../core/script/run.sh" "database:single" "${currentPath}/drop/database.sh"

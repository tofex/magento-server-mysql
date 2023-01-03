#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help      Show this message
  --useExtra  Use specified extra anonymize database (yes/no), default: yes

Example: ${scriptName}
EOF
}

useExtra=

source "${currentPath}/../core/prepare-parameters.sh"

if [[ -z "${useExtra}" ]]; then
  useExtra="yes"
fi

if [[ "${useExtra}" == "yes" ]]; then
  "${currentPath}/../core/script/run.sh" "databaseAnonymize:single" "${currentPath}/anonymize/database-anonymize.sh" \
    --anonymizeProcedureFileName "file:${currentPath}/anonymize/anonymize.sql"
else
  "${currentPath}/../core/script/run.sh" "database:single" "${currentPath}/anonymize/database.sh" \
    --anonymizeProcedureFileName "file:${currentPath}/anonymize/anonymize.sql"
fi

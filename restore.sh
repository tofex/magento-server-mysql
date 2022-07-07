#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name, default: system
  -d  Download file from Google storage
  -a  Access token to Google storage (optional)
  -m  Mode (dev/test/live)
  -f  Use this file, when not downloading from storage (optional)
  -t  Path to temp directory
  -r  Remove after import (optional)

Example: ${scriptName} -m dev -d -t /tmp
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system=
accessToken=
download=0
mode=
dumpFile=
tempDir=
remove=0

while getopts hs:da:m:f:t:r? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    d) download=1;;
    a) accessToken=$(trim "$OPTARG");;
    m) mode=$(trim "$OPTARG");;
    f) dumpFile=$(trim "$OPTARG");;
    t) tempDir=$(trim "$OPTARG");;
    r) remove=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${system}" ]]; then
  system="system"
fi

if [[ -z "${mode}" ]] && [[ -z "${dumpFile}" ]]; then
  usage
  exit 1
fi

if [[ -z "${dumpFile}" ]] && [[ "${system}" == "system" ]] && [[ "${mode}" != "dev" ]] && [[ "${mode}" != "test" ]] && [[ "${mode}" != "live" ]]; then
  echo "Invalid mode"
  echo ""
  usage
  exit 1
fi

if [[ -z "${tempDir}" ]]; then
  tempDir="/tmp/mysql"
fi

echo "--- Restoring database ---"

if [[ "${download}" == 1 ]]; then
  if [[ -z "${accessToken}" ]]; then
    "${currentPath}/download-dump.sh" -s "${system}" -m "${mode}"
  else
    "${currentPath}/download-dump.sh" -s "${system}" -m "${mode}" -a "${accessToken}"
  fi
fi

if [[ "${download}" == 1 ]] || [[ -z "${dumpFile}" ]]; then
  dumpPath="${currentPath}/../var/mysql/dumps"

  mkdir -p "${dumpPath}"

  date=$(date +%Y-%m-%d)
  dumpFile="${dumpPath}/mysql-${mode}-${date}.sql.gz"
fi

echo "Using dump file: ${dumpFile}"

if [[ ! -f "${dumpFile}" ]]; then
  echo "Required file not found at: ${dumpFile}"

  if [[ "${download}" == 1 ]]; then
    dumpFile="${dumpPath}/mysql-${mode}-${date}.zip"

    echo "Using dump file: ${dumpFile}"

    if [[ ! -f "${dumpFile}" ]]; then
      echo "Required file not found at: ${dumpFile}"
      exit 1
    fi
  else
    exit 1
  fi
fi

"${currentPath}/init.sh" -s "${system}"
"${currentPath}/import.sh" -i "${dumpFile}" -t "${tempDir}"

if [[ "${remove}" == 1 ]]; then
  echo "Removing downloaded dump: ${dumpFile}"
  rm -rf "${dumpFile}"
fi

#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help                Show this message
  --download            Download file from storage
  --mode                Mode (dev/test/live)
  --dumpFile            Use this file, when not downloading from storage (optional)
  --tempDir             Path to temp directory
  --remove              Remove after import (optional)
  --gcpAccessToken      By specifying a GCP access token, the dump will be downloaded from GCP
  --pCloudUserName      By specifying a pCloud username name and password, the dump will be downloaded from pCloud
  --pCloudUserPassword  By specifying a pCloud username name and password, the dump will be downloaded from pCloud

Example: ${scriptName} --mode dev --download --tempDir /tmp
EOF
}

download=0
mode=
dumpFile=
tempDir=
remove=0
gcpAccessToken=
pCloudUserName=
pCloudUserPassword=

source "${currentPath}/../core/prepare-parameters.sh"

if [[ -z "${mode}" ]] && [[ -z "${dumpFile}" ]]; then
  usage
  exit 1
fi

if [[ -z "${dumpFile}" ]] && [[ "${mode}" != "dev" ]] && [[ "${mode}" != "test" ]] && [[ "${mode}" != "live" ]]; then
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
  if [[ -n "${gcpAccessToken}" ]]; then
    "${currentPath}/download-dump.sh" --mode "${mode}" --gcpAccessToken "${gcpAccessToken}"
  elif [[ -n "${pCloudUserName}" ]] && [[ -n "${pCloudUserPassword}" ]]; then
    "${currentPath}/download-dump.sh" --mode "${mode}" --pCloudUserName "${pCloudUserName}" --pCloudUserPassword "${pCloudUserPassword}"
  else
    "${currentPath}/download-dump.sh" --mode "${mode}"
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

"${currentPath}/init.sh"
"${currentPath}/import.sh" --importFile "${dumpFile}" --tempDir "${tempDir}"

if [[ "${remove}" == 1 ]]; then
  echo "Removing downloaded dump: ${dumpFile}"
  rm -rf "${dumpFile}"
fi

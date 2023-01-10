#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help                Show this message
  --mode                Mode (dev/test/live)
  --date                Date of the file, default: current date
  --bucketName          The name of the bucket, default: mysql
  --gcpAccessToken      By specifying a GCP access token, the dump will be downloaded from GCP
  --pCloudUserName      By specifying a pCloud username name and password, the dump will be downloaded from pCloud
  --pCloudUserPassword  By specifying a pCloud username name and password, the dump will be downloaded from pCloud

Example: ${scriptName} --mode dev
EOF
}

trim()
{
  echo -n "$1" | xargs
}

mode=
date=
bucketName=
gcpAccessToken=
pCloudUserName=
pCloudUserPassword=

source "${currentPath}/../core/prepare-parameters.sh"

if [[ -z "${mode}" ]]; then
  usage
  exit 1
fi

if [[ -z "${date}" ]]; then
  date=$(date +%Y-%m-%d)
fi

if [[ -z "${bucketName}" ]]; then
  bucketName="mysql"
fi

if [ ! -f "${currentPath}/../env.properties" ]; then
  echo "No environment specified!"
  exit 1
fi

projectId=$(ini-parse "${currentPath}/../env.properties" "yes" "system" "projectId")

if [ -z "${projectId}" ]; then
  echo "No project id in environment!"
  exit 1
fi

if [[ -n "${gcpAccessToken}" ]]; then
  storage="GCP"
fi

if [[ -n "${pCloudUserName}" ]] && [[ -n "${pCloudUserPassword}" ]]; then
  storage="pCloud"
fi

if [[ -z "${storage}" ]]; then
  echo "Please select cloud storage:"
  select storage in GCP pCloud; do
    case "${storage}" in
      GCP)
        echo "Please specify access token to Google storage, followed by [ENTER]:"
        read -r gcpAccessToken
        break
        ;;
      pCloud)
        echo "Please specify user name of pCloud storage, followed by [ENTER]:"
        read -r pCloudUserName
        echo "Please specify user password of pCloud storage, followed by [ENTER]:"
        read -r pCloudUserPassword
        break
        ;;
      *)
        echo "Invalid option $REPLY"
        ;;
    esac
  done
fi

dumpPath="${currentPath}/../var/mysql/dumps"

mkdir -p "${dumpPath}"

downloadFileName="${projectId}-${mode}.sql.gz"
targetFileName="mysql-${mode}-${date}.sql.gz"

if [[ "${storage}" == "GCP" ]]; then
  fileUrl="https://www.googleapis.com/download/storage/v1/b/${bucketName}/o/${downloadFileName}?alt=media"
  echo "Checking url: ${fileUrl}"
  fileFound=$(curl -s --head -H "Authorization: Bearer ${gcpAccessToken}" "${fileUrl}" | head -n 1 | grep -c "HTTP/2 2" || true)
  if [[ "${fileFound}" == 0 ]]; then
    fileFound=$(curl -s --head -H "Authorization: Bearer ${gcpAccessToken}" "${fileUrl}" | head -n 1 | grep -c "HTTP/1.1 2" || true)
  fi

  if [[ "${fileFound}" == 0 ]]; then
    downloadFileName="${projectId}-${mode}.zip"
    targetFileName="mysql-${mode}-${date}.zip"

    fileUrl="https://www.googleapis.com/download/storage/v1/b/${bucketName}/o/${downloadFileName}?alt=media"
    echo "Checking url: ${fileUrl}"
    fileFound=$(curl -s --head -H "Authorization: Bearer ${gcpAccessToken}" "${fileUrl}" | head -n 1 | grep -c "HTTP/2 2" || true)
    if [[ "${fileFound}" == 0 ]]; then
      fileFound=$(curl -s --head -H "Authorization: Bearer ${gcpAccessToken}" "${fileUrl}" | head -n 1 | grep -c "HTTP/1.1 2" || true)
    fi
    if [[ "${fileFound}" == 0 ]]; then
      echo "Dump file not found or accessible!"
      exit 1
    fi
  fi

  echo "Downloading file from url: ${fileUrl}"
  if [[ $(type -t logDisable) == "function" ]]; then
    logDisable
  fi
  curl -X GET -H "Authorization: Bearer ${gcpAccessToken}" -o "${dumpPath}/${targetFileName}" "${fileUrl}"
  if [[ $(type -t logEnable) == "function" ]]; then
    logEnable
  fi
elif [[ "${storage}" == "pCloud" ]]; then
  fileUrl="https://eapi.pcloud.com/getfilelink?path=/${bucketName}/${downloadFileName}&getauth=1&logout=1&username=${pCloudUserName}&password=${pCloudUserPassword}"
  echo "Checking url: ${fileUrl}"
  fileUrlData=$(curl -s "${fileUrl}")
  fileUrlHost=$(echo "${fileUrlData}" | jq -r '.hosts[]' | head -n 1)
  fileUrlPath=$(echo "${fileUrlData}" | jq -r '.path')
  fileUrl="https://${fileUrlHost}${fileUrlPath}"

  echo "Downloading file from url: ${fileUrl}"
  if [[ $(type -t logDisable) == "function" ]]; then
    logDisable
  fi
  curl -X GET -o "${dumpPath}/${targetFileName}" "${fileUrl}"
  if [[ $(type -t logEnable) == "function" ]]; then
    logEnable
  fi
fi

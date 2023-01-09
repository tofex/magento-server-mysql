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
  --gpcAccessToken      By specifying a GPC access token, the dump will be uploaded to GPC
  --pCloudUserName      By specifying a pCloud username name and password, the dump will be uploaded to pCloud
  --pCloudUserPassword  By specifying a pCloud username name and password, the dump will be uploaded to pCloud

Example: ${scriptName} --mode dev --date 2018-06-05
EOF
}

mode=
date=
bucketName=
gpcAccessToken=
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

fileName="mysql-${mode}-${date}.sql.gz"
file="${currentPath}/../var/mysql/dumps/${fileName}"

if [ ! -f "${file}" ]; then
  echo "Requested upload file: ${file} does not exist!"
  exit 1
fi

curl=$(which curl)
if [ -z "${curl}" ]; then
  echo "Curl is not available!"
  exit 1
fi

if [[ -n "${gpcAccessToken}" ]]; then
  storage="GPC"
fi

if [[ -n "${pCloudUserName}" ]] && [[ -n "${pCloudUserPassword}" ]]; then
  storage="pCloud"
fi

if [[ -z "${storage}" ]]; then
  echo "Please select cloud storage:"
  select storage in GPC pCloud; do
    case "${storage}" in
      GPC)
        echo "Please specify access token to Google storage, followed by [ENTER]:"
        read -r gpcAccessToken
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

if [[ "${storage}" == "GPC" ]]; then
  echo "Uploading dump at: ${file} to Google Cloud Storage"
  curl -X POST \
    -T "${file}" \
    -H "Authorization: Bearer ${gpcAccessToken}" \
    -H "Content-Type: application/x-gzip" \
    "https://www.googleapis.com/upload/storage/v1/b/${bucketName}/o?uploadType=media&name=${fileName}"
elif [[ "${storage}" == "pCloud" ]]; then
  echo "Uploading dump at: ${file} to pCloud"
  curl -F "file=@${file}" "https://eapi.pcloud.com/uploadfile?path=/${bucketName}&getauth=1&logout=1&username=${pCloudUserName}&password=${pCloudUserPassword}"
fi

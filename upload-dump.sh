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
  --gcpAccessToken      By specifying a GCP access token, the dump will be uploaded to GCP
  --pCloudUserName      By specifying a pCloud username name and password, the dump will be uploaded to pCloud
  --pCloudUserPassword  By specifying a pCloud username name and password, the dump will be uploaded to pCloud

Example: ${scriptName} --mode dev --date 2018-06-05
EOF
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

file="${currentPath}/../var/mysql/dumps/mysql-${mode}-${date}.sql.gz"
uploadFileName="${projectId}-${mode}.sql.gz"

if [ ! -f "${file}" ]; then
  echo "Requested upload file: ${file} does not exist!"
  exit 1
fi

curl=$(which curl)
if [ -z "${curl}" ]; then
  echo "Curl is not available!"
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

if [[ "${storage}" == "GCP" ]]; then
  echo "Uploading dump at: ${file} to Google Cloud Storage"
  curl -X POST \
    -T "${file}" \
    -H "Authorization: Bearer ${gcpAccessToken}" \
    -H "Content-Type: application/x-gzip" \
    "https://www.googleapis.com/upload/storage/v1/b/${bucketName}/o?uploadType=media&name=${uploadFileName}"
elif [[ "${storage}" == "pCloud" ]]; then
  echo "Uploading dump at: ${file} to pCloud"
  curl -F "file=@${file};filename=${uploadFileName}" "https://eapi.pcloud.com/uploadfile?path=/${bucketName}&getauth=1&logout=1&username=${pCloudUserName}&password=${pCloudUserPassword}"
fi

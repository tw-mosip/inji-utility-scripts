#!/bin/bash

UIN_VID=$1

if [[ -z ${UIN_VID} ]];then
    echo "Usage: " >&2
    echo "1. ./download-vc.sh <UIN/VID>" >&2
    echo "2. ./download-vc.sh <UIN/VID> <ENV>" >&2
    echo "" >&2
    echo "Example: " >&2
    echo "# Without env argument, defaults to dev2  -->  ./download-vc.sh 3718934652" >&2
    echo "# With env argument                       -->  ./download-vc.sh 3718934652 dev2 " >&2
    exit 1
fi

ID_TYPE="UIN"
if [[ ${#UIN_VID} -eq 16 ]];then
    ID_TYPE="VID"
fi

echo "ID Type: ${ID_TYPE}" >&2

ENV=$2
if [[ -z ${ENV} ]];then
    ENV="dev2"
fi

echo "Env: ${ENV}" >&2

# https://www.tutorialspoint.com/guide-to-generate-random-numbers-in-linux#:~:text=To%20generate%20a%20random%20number%20within%20a%20specific%20range%2C%20you,is%20using%20the%20openssl%20command.
function genTransactionId() {
    RAN_ID=$(( RANDOM%9999999999+1000000000 ))
    echo $RAN_ID
}

TX_ID=$( genTransactionId )

echo "Generated Random Tx Id: $TX_ID" >&2

# 1. Req OTP
REQ_OTP_RESPONSE=`curl --location --request POST 'https://api.'"${ENV}"'.mosip.net/residentmobileapp/req/otp' \
--header 'Content-Type: application/json' \
--data-raw '{
  "individualId": "'"${UIN_VID}"'",
  "individualIdType": "'"${ID_TYPE}"'",
  "otpChannel": [
    "EMAIL",
    "PHONE"
  ],
  "transactionID": "'"${TX_ID}"'"
}'`

if [[ $? -ne 0 ]];then
    exit 1
fi

echo $REQ_OTP_RESPONSE >&2

# 2. Credential Req
CRED_REQ_RESP=`curl --location --request POST 'https://api.'"${ENV}"'.mosip.net/residentmobileapp/credentialshare/request' \
--header 'Content-Type: application/json' \
--data-raw '{
    "individualId": "'"${UIN_VID}"'",
    "individualIdType": "'"${ID_TYPE}"'",
    "otp": "111111",
    "transactionID": "'"${TX_ID}"'"
}'`

if [[ $? -ne 0 ]];then
    exit 1
fi

echo $CRED_REQ_RESP >&2

REQUEST_ID=`echo $CRED_REQ_RESP|jq '.response.requestId'|tr -d '"'`

echo "Received RequestId: $REQUEST_ID" >&2

ISSUED=
while
    sleep 1

    # 3. Status of Credential Req
    CRED_STATUS_RESP=`curl --location --request GET 'https://api.'"${ENV}"'.mosip.net/residentmobileapp/credentialshare/request/status/'${REQUEST_ID}''`

    if [[ $? -ne 0 ]];then
        exit 1
    fi

    echo $CRED_STATUS_RESP >&2

    STATUS_CODE=`echo $CRED_STATUS_RESP|jq '.response.statusCode'`

    echo "Status of VC Issuance: ${STATUS_CODE}" >&2

    if [[ ${STATUS_CODE} = "\"FAILED\"" ]];then
        echo "Unable to generate VC" >&2
        exit 1
    fi

    [ "${STATUS_CODE}" != "\"ISSUED\"" ]
do :; done

echo "VC issue Completed, Downloading VC" >&2

# 4. VC Download
DOWNLOAD_VC_RESP=`curl --location --request POST 'https://api.'"${ENV}"'.mosip.net/residentmobileapp/credentialshare/download' \
--header 'Content-Type: application/json' \
--data-raw '{
    "individualId": "'"${UIN_VID}"'",
    "requestId": "'"${REQUEST_ID}"'"
}'`

if [[ $? -ne 0 ]];then
    exit 1
fi

echo $DOWNLOAD_VC_RESP

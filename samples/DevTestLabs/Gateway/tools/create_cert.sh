#!/bin/bash -e

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

cdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
tdir="$cdir/tmp"

if [ ! -d "$tdir" ]; then
    echo "Creating temporary directory $tdir"
    mkdir "$tdir"
fi

secretFile="$tdir/cert_in.pem"
exportFile="$tdir/cert_out.p12"

# create output file for local development
if [ -z "$AZ_SCRIPTS_OUTPUT_PATH" ]; then
    AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY="$tdir"
    AZ_SCRIPTS_PATH_SCRIPT_OUTPUT_FILE_NAME="scriptoutputs.json"
    AZ_SCRIPTS_OUTPUT_PATH="$AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY/$AZ_SCRIPTS_PATH_SCRIPT_OUTPUT_FILE_NAME"
fi

certName="SignCert"

certPolicy='{
    "issuerParameters": {
        "name": "Self"
    },
    "keyProperties": {
        "exportable": true,
        "keySize": 2048,
        "keyType": "RSA",
        "reuseKey": false
    },
    "lifetimeActions": [
        {
            "action": { "actionType": "AutoRenew" },
            "trigger": { "daysBeforeExpiry": 60 }
        }
    ],
    "secretProperties": {
        "contentType": "application/x-pem-file"
    },
    "x509CertificateProperties": {
        "ekus": [ "1.3.6.1.5.5.7.3.2" ],
        "keyUsage": [ "digitalSignature" ],
        "subject": "CN=Azure DTL Gateway",
        "validityInMonths": 12
    }
}'

helpText=$(cat << endHelp

Signing Certificate Utility

Options:
  -h  View this help output text again.

  -v  KeyVault name.

  -n  Certificate name in KeyVault. Defaults to SignCert

Examples:

    $ create_cert.sh -v mykeyvault

endHelp
)

# show help text if called with no args
if (($# == 0)); then
    echo "$helpText" >&2; exit 0
fi

# get arg values
while getopts ":v:n:h:" opt; do
    case $opt in
        v)  vaultName=$OPTARG;;
        n)  certName=$OPTARG;;
        h)  echo "$helpText" >&2; exit 0;;
        \?) echo "    Invalid option -$OPTARG $helpText" >&2; exit 1;;
        :)  echo "    Option -$OPTARG requires an argument $helpText." >&2; exit 1;;
    esac
done

# check for the azure cli
if ! [ -x "$(command -v az)" ]; then
    echo 'Error: az command is not installed.\nThe Azure CLI is required to run this deploy script. Please install the Azure CLI, run az login, then try again.' >&2
    exit 1
fi

# check for jq
if ! [ -x "$(command -v jq)" ]; then
    echo 'Error: jq command is not installed.\njq is required to run this deploy script. Please install jq from https://stedolan.github.io/jq/download/, then try again.' >&2
    exit 1
fi


# private key is added as a secret that can be retrieved in the Resource Manager template
echo "Creating new certificate '$certName'"
az keyvault certificate create --vault-name $vaultName -n $certName -p "$certPolicy"

echo "Getting certificate details"
cert=$( az keyvault certificate show --vault-name $vaultName -n $certName )

echo "Getting secret id for certificate '$certName'"
sid=$( echo $cert | jq -r '.sid' )

echo "Getting thumbprint for certificate '$certName'"
thumbprint=$( echo $cert | jq -r '.x509ThumbprintHex' )

echo "Downloading certificate '$certName'"
az keyvault secret download --id $sid -f "$secretFile"

echo "Generating random password for certificate export"
password=$( openssl rand -base64 32 | tr -d /=+ | cut -c -16 )

echo "Exporting certificate file '$exportFile'"
openssl pkcs12 -export -in "$secretFile" -out "$exportFile" -password pass:$password -name "Azure DTL Gateway"
certBase64=$( openssl base64 -A -in "$exportFile" )

echo "{ \"thumbprint\": \"$thumbprint\", \"password\": \"$password\", \"base64\": \"$certBase64\" }" > $AZ_SCRIPTS_OUTPUT_PATH

echo "Cleaning up temporary files"
rm -rf "$tdir"

echo "Deleting script runner managed identity"
az identity delete --ids "$AZ_SCRIPTS_USER_ASSIGNED_IDENTITY"

echo "Done."

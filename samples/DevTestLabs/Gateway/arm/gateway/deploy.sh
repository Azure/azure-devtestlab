#!/bin/sh

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -e

NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'

die() { echo "${RED}Error: $1${NC}" >&2; exit 1; }

cdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

template="$cdir/azuredeploy.json"
artifactsSource="$cdir/artifacts"

helpText=$(cat << endHelp

Remote Desktop Gateway Deploy Utility

Options:
  -h  View this help output text again.

  -s  Name or ID of subscription.
        You can configure the default subscription using az account set -s NAME_OR_ID.

  -g  Resource Group: The Name for the new Azure Resource Group to create.
        The value must be a string.  Resource Group names are case insensitive.
        Alphanumeric, underscore, parentheses, hyphen, period (except at the end) are valid.

  -l  Location. Values from: az account list-locations.
        You can configure the default location using az configure --defaults location=<location>.

  -u  The admin username for the gateway vms.

  -p  The admin password for the gateway vms.

  -c  Path to the SSL certificate .pfx or .p12 file.

  -k  The SSL certificate password for installation.

  -i  Number of vms in the gateway scale set. default: 1

Examples:

    $ deploy.sh -g MyResoruceGroup -l eastus -u DevUser -p SoSecure1 -c ./Cert.p12 -k 12345

endHelp
)
helpText="${NC}$helpText${NC}\n"

# show help text if called with no args
if (($# == 0)); then
    echo "$helpText" >&2; exit 0
fi

# defaults
instances=1
# sub=$( az account show | jq -r '.id' )

# get arg values
while getopts ":hs:g:l:u:p:c:k:i:" opt; do
    case $opt in
        s)  sub=$OPTARG;;
        g)  rg=$OPTARG;;
        l)  region=$OPTARG;;
        u)  adminUsername=$OPTARG;;
        p)  adminPassword=$OPTARG;;
        c)  sslCert=$OPTARG;;
        k)  sslCertPassword=$OPTARG;;
        i)  instances==$OPTARG;;
        h)  echo "$helpText" >&2; exit 0;;
        \?) die "Invalid option -$OPTARG \n$helpText";;
        :)  die "Option -$OPTARG requires an argument \n$helpText.";;
    esac
done

echo ""

# check for jq
[ -x "$(command -v jq)" ] || die "jq command is not installed.\njq is required to run this deploy script. Please install jq from https://stedolan.github.io/jq/download/, then try again."
# check for the azure cli
[ -x "$(command -v az)" ] || die "az command is not installed.\nThe Azure CLI is required to run this deploy script. Please install the Azure CLI, run az login, then try again."

# temp fix start
verCheck() { printf "%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
azversion=$( az version | jq -r '."azure-cli"' ) # TODO remove this after new version released 3/2
[ $(verCheck $azversion) -gt $(verCheck 2.18.0) ] && die "There is a bug in az cli 2.19.0+ storage module that prevents this script from executing correctly. Please downgrade to version 2.18.0 and run this script again."
# temp fix end


[ ! -z "$sub" ] || die "-s must have a value\n$helpText"
[ ! -z "$rg" ] || die "-g must have a value\n$helpText"
[ ! -z "$region" ] || die "-l must have a value\n$helpText"
[ ! -z "$adminUsername" ] || die "-u must have a value\n$helpText"
[ ! -z "$adminPassword" ] || die "-p must have a value\n$helpText"
[ ! -z "$sslCert" ] || die "-c must have a value\n$helpText"
[ ! -z "$sslCertPassword" ] || die "-k must have a value\n$helpText"
[ ! -z "$instances" ] || die "-i must have a value\n$helpText"

# make sure sslCert is a path to a file
[ -f "$sslCert" ] || die "-c $sslCert not found. Please check the path is correct and try again."


# check if logged in to azure cli
az account show -s $sub 1> /dev/null

# check if the resource group exists. if not, create it
az group show --subscription $sub -g $rg 1> /dev/null || echo "Creating resource group '$rg'." && az group create --subscription $sub -g $rg -l $region 1> /dev/null


echo "\nParsing SSL certificate\n"
sslCertBase64=$( base64 $sslCert )
sslCertThumbprint=$( openssl pkcs12 -in $sslCert -nodes -passin pass:$sslCertPassword | openssl x509 -noout -fingerprint | cut -d "=" -f 2 | sed 's/://g' )
sslCertCommonName=$( openssl pkcs12 -in $sslCert -nodes -passin pass:$sslCertPassword | openssl x509 -noout -subject | rev | cut -d "=" -f 1 | rev | sed 's/ //g' )


echo "\nDeploying arm template"
deploy=$(az deployment group create --subscription $sub -g $rg \
         --template-file $template \
         --parameters adminUsername=$adminUsername \
                      adminPassword=$adminPassword \
                      sslCertificate=$sslCertBase64 \
                      sslCertificatePassword=$sslCertPassword \
                      sslCertificateThumbprint=$sslCertThumbprint | jq '.properties.outputs' )

[ -z "$deploy" ] && "Failed to deploy arm template - aborting."


if [ -d "$artifactsSource" ]; then
  artifacts=$( echo $deploy | jq '.artifactsStorage.value' )
  artifactsAccount=$( echo $artifacts | jq -r '.account' )
  artifactsContainer=$( echo $artifacts | jq -r '.container' )

  echo "\nSynchronizing artifacts"
  az storage blob sync --subscription $sub --account-name $artifactsAccount -c $artifactsContainer -s "$artifactsSource" > /dev/null 2>&1 &
fi


gateway=$( echo $deploy | jq '.gateway.value' )
gatewayIP=$( echo $gateway | jq -r '.ip' )
gatewayFQDN=$( echo $gateway | jq -r '.fqdn' )
gatewayScaleSet=$( echo $gateway | jq -r '.scaleSet' )
gatewayFunction=$( echo $gateway | jq -r '.function' )

echo "\nScaling gateway to $instances instances"
az vmss scale --subscription $sub -g $rg -n $gatewayScaleSet --new-capacity $instances > /dev/null 2>&1 &

if [ "$gatewayFunction" != "null" ]; then
  echo "\nGetting gateway token"
  gatewayToken=$(az functionapp function keys list --subscription $sub -g $rg -n $gatewayFunction --function-name CreateToken | jq -r '.gateway' )

  if [ "$gatewayToken" == "null" ]; then
    echo "No gateway token found, creating"
    gatewayToken=$(az functionapp function keys set --subscription $sub -g $rg -n $gatewayFunction --function-name CreateToken --key-name gateway --query value -o tsv )
  fi
fi


echo "\nDone."

if [ ! -z "$sslCertCommonName" ]; then
  echo "\n\n${GREEN}Register Remote Desktop Gateway with your DNS using one of the following two options:${NC}\n"
  echo "${GREEN}  - Create an A-Record:     $sslCertCommonName -> $gatewayIP ${NC}"
  echo "${GREEN}  - Create an CNAME-Record: $sslCertCommonName -> $gatewayFQDN ${NC}"
  if [ ! -z "$gatewayToken" ]; then
    echo "\n\n${GREEN}Use the following to configure your labs to use the gateway:${NC}\n"
    echo "${GREEN}  - Gateway hostname:     $sslCertCommonName ${NC}"
    echo "${GREEN}  - Gateway token secret: $gatewayToken ${NC}"
  fi
fi

echo ""

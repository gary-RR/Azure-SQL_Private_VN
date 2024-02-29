#!/bin/bash

function check_for_input_blank(){
    param_name=$1
    param_val=$2

    if [[ -z "$2" ]]; then
        message="Error: ${1} cannot be blank"
        echo $message>&2
        exit 1
    fi
}

env=$3

if [[ -z "$env" || "$env" != "test" && "$env" != "production" ]]; then
    echo "Error: Invalid environment. Please set 'env' to either 'Test' or 'Production'." >&2
    exit 1
fi

check_for_input_blank "Application name" "$1"
check_for_input_blank "Resource Group name" "$2"
check_for_input_blank "Github Org name" "$4"
check_for_input_blank "Github Repo name" "$5"

appName="${1}-${3}"
resourceGroup="${2}-${3}"
githubOrganizationName="${4}"
githubRepositoryName="${5}"

resourceGroupResourceId=$(az group create --name "${resourceGroup}" --location westus3 --query id --output tsv)
echo "${resourceGroupResourceId}"

applicationRegistrationAppId=$(az ad app list --display-name $appName --query "[].appId" -o tsv)
if [ -z "$applicationRegistrationAppId" ]; then
# Create the AD app if it doesn't exist
  echo 'Creating Federated Credentials and Service Principal..'
  applicationRegistrationDetails=$(az ad app create --display-name "${appName}")
  applicationRegistrationObjectId=$(echo $applicationRegistrationDetails | jq -r '.id')
  applicationRegistrationAppId=$(echo $applicationRegistrationDetails | jq -r '.appId')

  az ad app federated-credential create \
   --id $applicationRegistrationObjectId \
   --parameters "{\"name\":\"${githubRepositoryName}-${env}\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:${githubOrganizationName}/${githubRepositoryName}:environment:Test\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

    az ad app federated-credential create \
    --id $applicationRegistrationObjectId \
    --parameters "{\"name\":\"${githubRepositoryName}-${env}-branch\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:${githubOrganizationName}/${githubRepositoryName}:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

    az ad sp create --id $applicationRegistrationObjectId
else
   applicationRegistrationObjectId=$(az ad app list --display-name $1 --query "[].id" -o tsv)
fi

resourceGroupResourceId=${resourceGroupResourceId:1}

az role assignment create \
   --assignee $applicationRegistrationAppId \
   --role Contributor \
   --scope $resourceGroupResourceId

# echo $applicationRegistrationObjectId , $applicationRegistrationAppId

# ./creat_pre_req.sh Azure-SQL_Private_VN AzureSQLPrivateVN test 'gary-RR' 'Azure-SQL_Private_VN'
      

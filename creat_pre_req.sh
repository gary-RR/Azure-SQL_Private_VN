#!/bin/bash

echo "Args: ${1} ${2} ${3} ${4} ${5} "

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

applicationRegistrationAppId=$(az ad app list --display-name $appName --query "[].appId" -o tsv)

applicationRegistrationDetails=$(az ad app create --display-name "${appName}")

#If this is a new ad app registration
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

# If the ad app already exists, delete its currnt SP so it can be recreated and bind to the new resource group.        
else   
   # First delete the role assignment. This is due to a bug in the current Azure API where if a SP is deleted without its role binding, it doesn't cleanly delete the SP. 
   spId=$(az ad sp list --display-name ${appName} --query "[].id" -o tsv)
   id=$(az role assignment list --assignee $spId --all --query "[].id" -o tsv)
   id=${id:1}
   az role assignment delete --ids $id
   # Delete the SP
   az ad sp delete --id ${applicationRegistrationAppId}  
   applicationRegistrationObjectId=$(az ad app list --display-name $appName --query "[].id" -o tsv)  
fi

az ad sp create --id $applicationRegistrationObjectId
#Remove its leading "/" due to a bug in Git bash where an extra leading "/" is added.
resourceGroupResourceId=${resourceGroupResourceId:1}

# echo "Assigning SP contribute role to resource group...."
az role assignment create \
   --assignee $applicationRegistrationAppId \
   --role Contributor \
   --scope $resourceGroupResourceId

# echo "applicationRegistrationObjectId: ${applicationRegistrationObjectId}" 
CAP_ENV=$(echo ${env} | tr '[:lower:]' '[:upper:]')
# echo "AZURE_CLIENT_ID_${CAP_ENV}: ${applicationRegistrationAppId}"
app_id="AZURE_CLIENT_ID_${CAP_ENV}: ${applicationRegistrationAppId}"
# echo ${app_id}
echo ${app_id}     

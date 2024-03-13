appName='Azure-SQL_Private_VN'
resourceGroup='AzureSQLPrivateVN'
githubOrganizationName='gary-RR'
githubRepositoryName='Azure-SQL_Private_VN'
env=''

env='test'
./creat_pre_req.sh ${appName} ${resourceGroup} ${env} ${githubOrganizationName} ${githubRepositoryName}

env='production'
./creat_pre_req.sh ${appName} ${resourceGroup} ${env} ${githubOrganizationName} ${githubRepositoryName}

echo "AZURE_CLIENT_ID_TEST: $testApplicationRegistrationAppId"
echo "AZURE_CLIENT_ID_PRODUCTION: $productionApplicationRegistrationAppId"
echo "AZURE_TENANT_ID: $(az account show --query tenantId --output tsv)"
echo "AZURE_SUBSCRIPTION_ID: $(az account show --query id --output tsv)"




#Clean up
env='test'
az group delete --resource-group "${resourceGroup}-${env}" --yes --no-wait
applicationRegistrationAppId=$(az ad app list --display-name "${appName}-${env}" --query "[].appId" -o tsv)
az ad app delete --id $applicationRegistrationAppId

env='production'
az group delete --resource-group "${resourceGroup}-${env}" --yes --no-wait
applicationRegistrationAppId=$(az ad app list --display-name "${appName}-${env}" --query "[].appId" -o tsv)
az ad app delete --id $applicationRegistrationAppId

# The following are not necessary, just shown if needed to delete them but not their respective applications.
# az ad app federated-credential delete --federated-credential-id  'Azure-SQL_Private_VN-test' --id $testApplicationRegistrationAppId
# az ad app federated-credential delete --federated-credential-id  'Azure-SQL_Private_VN-test-branch' --id $testApplicationRegistrationAppId
# az ad app list --display-name 'Azure-SQL_Private_VN-test'



git add .
git commit -m "Multi env and workflow components part1-fix18"
git push

# Experimentations*********************************************************************************************

az ad sp list --display-name 'Azure-SQL_Private_VN-test' --query "[].appId" -o tsv
az ad sp list --display-name 'Azure-SQL_Private_VN-test' --query "[].appOwnerOrganizationId" -o tsv

spId=$(az ad sp list --display-name 'Azure-SQL_Private_VN-test' --query "[].id" -o tsv)
az role assignment list --assignee $spId --all
id=$(az role assignment list --assignee $spId --all --query "[].id" -o tsv)
id=${id:1}
az role assignment delete --ids $id

# Lint
az bicep build --file ./deploy/modules/create_vnet_and_vpn.bicep
#Pre flight validation
az deployment group validate --resource-group rg-AzureSQLTest --template-file ./deploy/modules/create_vnet_and_vpn.bicep
# Deploy
az deployment group create --resource-group rg-AzureSQLTest --template-file ./deploy/modules/create_vnet_and_vpn.bicep

az group create --name AzureSQLTest --location centralus --query id --output tsv
# /subscriptions/e6566f19-3eb5-436b-904f-fdd540b4fd58/resourceGroups/AzureSQLTest
echo "AZURE_TENANT_ID: $(az account show --query tenantId --output tsv)"
echo "AZURE_SUBSCRIPTION_ID: $(az account show --query id --output tsv)"



# az deployment group create --resource-group AzureSQLTest --template-file azure_sql_private_endpoint.bicep --parameters role=Reader

az deployment group create --resource-group AzureSQLTest --template-file ./modules/create_vnet_and_vpn.bicep


#Clean up
az group delete --resource-group AzureSQLTest --yes --no-wait
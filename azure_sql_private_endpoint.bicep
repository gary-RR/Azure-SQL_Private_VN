param location string=resourceGroup().location
param sqlServerName string
param adminLoginName string
param adminPassword string
param databaseName string
param privateEndpointName string='sql-private-endpoint'
param privateDnsZoneGroupName string='sqlPrivateDnsZoneGroup'
param vmName string='testvm'
param vmSize string='Standard_A0'
param vmloginUser string='gary'
param vmloginPassword string='g@678219'

@maxLength(63)
param privateDnsZoneName string='privatelink${environment().suffixes.sqlServerHostname}'

@description('Select the type of environment you want to provision. Allowed values are Production and Test.')
@allowed([
  'Production'
  'Test'
])
param environmentType string

var environmentConfigurationMap = {
  Production: {
    appServicePlan: {
      sku: {
        name: 'S1'
        capacity: 1
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_LRS'
      }
    }
    sqlDatabase: {
      sku: {
        name: 'Standard'
        tier: 'Standard'
      }
    }
  }
  Test: {
    appServicePlan: {
      sku: {
        name: 'F1'
      }
    }
    storageAccount: {
      sku: {
        name: 'Standard_GRS'
      }
    }
    sqlDatabase: {
      sku: {
        name: 'Standard'
        tier: 'Standard'
      }
    }
  }
}

var vnetName='private_azure_sql_vnet1'

module createVnet 'modules/create_vnet_and_vpn.bicep' = {
  name: 'vnet'
  params: {
    location: location
    vnetName: vnetName
    tenanatID : subscription().tenantId
  }
}

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: sqlServerName
  location: location
  tags: {
    displayName: 'SqlServer'
  }
  properties: {
    administratorLogin: adminLoginName
    administratorLoginPassword: adminPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: environmentConfigurationMap[environmentType].sqlDatabase.sku
}

resource allowAzureTrafficFirewallRules 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'sqlFirewallRules'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }  
}

resource allowFrontEndVnetTrafficFirewallRules 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'allowfrontendTraffic'
  properties: {
    startIpAddress: parseCidr(createVnet.outputs.frontendSubnet.properties.addressPrefix).firstUsable
    endIpAddress: parseCidr(createVnet.outputs.frontendSubnet.properties.addressPrefix).lastUsable //creatVnet.outputs.endIPAddress
  }  
  
}

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: 'nic1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${vmName}vmip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: createVnet.outputs.backendSubnet.id
          }
        }
      }
    ]
  }
  dependsOn: [
    createVnet
  ]
}

resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmName}vm'
      adminUsername: vmloginUser
      adminPassword: vmloginPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-core'
        version: 'latest'
      }
      osDisk: {
        name: 'vmdisk1'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: createVnet.outputs.frontendSubnet.id 
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlServerConnection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
  
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global' 
  // properties: {}
}

resource privateDnsZone_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'privateDbDnsZoneName_var-link'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: createVnet.outputs.vnetId
    }
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  name: '${privateEndpointName}-group'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneGroupName
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]    
  }  
}

output sqlServerFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name


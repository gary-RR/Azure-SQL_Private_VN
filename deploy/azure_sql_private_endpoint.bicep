@description('mmm')
param location string=resourceGroup().location

@description('A unique suffix to add to resource names that need to be globally unique.')
@maxLength(13)
param resourceNameSuffix string = uniqueString(resourceGroup().id)

param appName string ='cosmo'

param vnetId string
param frontendSubnet object
param backendSubnet object

param createWindowsServer1 bool=false
param createLinuxServer1 bool=false
param createWindowsDesktop1 bool=true

param adminDBLoginName string
@secure()
param adminDBPassword string

param databaseName string

param vmSize string='Standard_A0'

param vmWindowsLoginUser string
@secure()
param vmWindowsLoginPassword string

param vmLinuxLoginUser string
@secure()
param vmLinuxLoginPassword string

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

var sqlServerName='sql-${appName}-${resourceNameSuffix}'
var privateEndpointName='pep-${appName}-${resourceNameSuffix}'
var privateDnsZoneName='prv-dns-zone-${appName}${environment().suffixes.sqlServerHostname}'
var privateDnsZoneLinkName='prv-dns-zone-vnet-lnk${appName}${environment().suffixes.sqlServerHostname}'
var privateDnsZoneGroupName='${appName}-PrivateDnsZoneGroup'
var vmWindowsServer1Name='vm-${appName}-hr'
var vmWindowsDesktop1Name='vm-${appName}-client'
var vmWLinuxName='vm-${appName}-stores'
var nicNameWindowServer1='nic-${vmWindowsServer1Name}'
var nicNameLinux='nic-${vmWLinuxName}'
var nicNameWindowsDesktop1='nic-${vmWindowsDesktop1Name}'

// module createVnet 'modules/create_vnet_and_vpn.bicep' = {
//   name: 'vnet'
//   params: {
//     location: location
//     tenanatID : subscription().tenantId
//   }
// }


resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: sqlServerName
  location: location
  tags: {
    displayName: 'SqlServer'
  }
  properties: {
    administratorLogin: adminDBLoginName
    administratorLoginPassword: adminDBPassword
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
    startIpAddress: parseCidr(frontendSubnet.properties.addressPrefix).firstUsable
    endIpAddress: parseCidr(frontendSubnet.properties.addressPrefix).lastUsable //creatVnet.outputs.endIPAddress
  }  
  
}

resource nicWindowsServer1 'Microsoft.Network/networkInterfaces@2020-06-01' = if (createWindowsServer1) {
  name: nicNameWindowServer1
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${vmWindowsServer1Name}vmip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: backendSubnet.id
          }
        }
      }
    ]
  }
  // dependsOn: [
  //   createVnet
  // ]
}


resource vmWindowsServer1 'Microsoft.Compute/virtualMachines@2020-06-01' = if (createWindowsServer1) {
  name: vmWindowsServer1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmWindowsServer1Name
      adminUsername: vmWindowsLoginUser
      adminPassword: vmWindowsLoginPassword
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
          id: nicWindowsServer1.id
        }
      ]
    }
  }
}

resource nicWindowsDesktop1 'Microsoft.Network/networkInterfaces@2020-06-01' = if (createWindowsDesktop1) {
  name: nicNameWindowsDesktop1
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${vmWindowsDesktop1Name}vmip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: frontendSubnet.id
          }
        }
      }
    ]
  }
  // dependsOn: [
  //   createVnet
  // ]
}

resource vmWindowsDesktop1 'Microsoft.Compute/virtualMachines@2020-06-01' = if (createWindowsDesktop1) {
  name: vmWindowsDesktop1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5' //vmSize
    }
    osProfile: {
      computerName: vmWindowsServer1Name
      adminUsername: vmWindowsLoginUser
      adminPassword: vmWindowsLoginPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: 'win11-21h2-avd'
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
          id: nicWindowsDesktop1.id
        }
      ]
    }
  }
}


resource nicLinuxServer1 'Microsoft.Network/networkInterfaces@2020-06-01' = if (createLinuxServer1) {
  name: nicNameLinux
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${vmWLinuxName}vmip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: frontendSubnet.id
          }
        }
      }
    ]
  }
  // dependsOn: [
  //   createVnet
  // ]
}

resource ubuntuVM 'Microsoft.Compute/virtualMachines@2020-06-01' = if (createLinuxServer1) {
  name: vmWLinuxName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS1_v2' // Choose an appropriate VM size
    }
    osProfile: {
      adminUsername: vmLinuxLoginUser
      adminPassword: vmLinuxLoginPassword
      computerName: vmWLinuxName
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicLinuxServer1.id
          properties: {
            primary: true
          }
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
      id: frontendSubnet.id 
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

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: privateDnsZoneLinkName
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnetId
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
// output privateEndPointIPAddress string=privateEndpoint.properties.ipConfigurations[0].properties.privateIPAddress
output sqlDatabaseName string = sqlDatabase.name





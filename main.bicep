param vneName string = 'private_azure_sql_vnet1'
param location string=resourceGroup().location
param sqlServerName string
param adminLoginName string
param adminPassword string
param databaseName string
param privateEndpointName string='mysql'
param privateDnsZoneGroupName string='sqlPrivateDnsZoneHroup'
param vmName string='testvm'
param vmSize string='Standard_A0'
param vmloginUser string='gary'
param vmloginPassword string='g@678219'
// param rg string = resourceGroup().name 

param tenanatID string=subscription().tenantId
var aadTenant ='https://login.microsoftonline.com/${tenanatID}'

var aadIssuer='https://sts.windows.net/${tenanatID}/'

// Audience: The Application ID of the "Azure VPN" Microsoft Entra Enterprise App.
// Azure Public: 41b23e61-6c1e-4545-b367-cd054e0ed4b4
// Azure Government: 51bb15d4-3a4f-4ebf-9dca-40096fe32426
// Azure Germany: 538ee9e6-310a-468d-afef-ea97365856a9
// Microsoft Azure operated by 21Vianet: 49f817b6-84ae-4cc0-928c-73f27289b3aa
var aadAudience='41b23e61-6c1e-4545-b367-cd054e0ed4b4'

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vneName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    // subnets: [
    //   {
    //     name: 'frontendSubnet'
    //     properties: {
    //       addressPrefix:  '10.0.0.0/24'
    //     }
    //   }
    //   {
    //     name: 'backendSubnet'
    //     properties: {
    //       addressPrefix:  '10.0.1.0/24'
    //     }
    //   }
    //   {
    //     name: 'gatewaySubnet'
    //     properties: {
    //       addressPrefix:  '10.0.2.0/24'
    //     }
    //   }
    // ]
  }
}

// 'Microsoft.Network/virtualNetworks/subnets@2020-06-01'
resource frontendSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' = {
  name: 'frontend'
  parent: vnet
  properties: {    
    addressPrefix: '10.0.0.0/24'
  }

  dependsOn: [
    vnet
  ]
}

resource backSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' = {
  name: 'backEend'
  parent: vnet
  properties: {    
    addressPrefix: '10.0.1.0/24'
  }

  dependsOn: [
    vnet,frontendSubnet
  ]
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' = {
  name: 'gatewaySubnet'
  parent: vnet
  properties: {    
    addressPrefix: '10.0.2.0/24'
  }
  
  dependsOn: [
    vnet, frontendSubnet, backSubnet
  ]
}

resource publicIPAddresses_pocgtway1_name_rsc 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'bicepBupIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'  
  }
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-05-01' = {
  name: 'vpngtway'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        // id: resourceId(rg, 'Microsoft.Network/virtualNetworkGateways/ipConfigurations', vpnGateway.name ,'default')
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddresses_pocgtway1_name_rsc.id
          }
          subnet: {
            id: gatewaySubnet.id 
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    enableBgp: false
    activeActive: false
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          '172.16.201.0/24'
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'
      ]
      vpnAuthenticationTypes: [
        'AAD'
      ]
      vpnClientRootCertificates: []
      vpnClientRevokedCertificates: []
      // vngClientConnectionConfigurations: []
      radiusServers: []
      vpnClientIpsecPolicies: []
      aadTenant: aadTenant
      aadAudience: aadAudience
      aadIssuer: aadIssuer
    }    
  }
}


@maxLength(63)
param privateDnsZoneName string='sqlPrivateDnsZone.com'

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
    startIpAddress: parseCidr(frontendSubnet.properties.addressPrefix).firstUsable
    endIpAddress: parseCidr(frontendSubnet.properties.addressPrefix).lastUsable //creatVnet.outputs.endIPAddress
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
            // properties: {
            //   addressPrefix: backSubnet.properties.addressPrefix
            // }
            id: backSubnet.id
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
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
  dependsOn: [
    nic
  ]
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

resource rivateDnsZone_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'privateDbDnsZoneName_var-link'
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnet.id
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


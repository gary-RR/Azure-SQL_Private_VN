@description('A generic name for all your resources created with this ARM Template.')
param stackName string

@description('Object Id of your AAD user or whoever needs access to resources such as KeyVault.')
param aadUserObjectId string

@description('Name of your AAD user or whoever needs access to resources such as Azure SQL.')
param aadUsername string

@description('The administrator password of the VM and SQL Server.')
param loginUser string

@description('Certificate used for the P2S VPN.')
param p2sRootCert string

@description('The administrator password of the VM and SQL Server.')
@secure()
param loginPassword string

@description('Private DNS zone name for database.')
param privateDbDnsZoneName string = 'privatelink${environment().suffixes.sqlServerHostname}'

@description('Location for all the resources created.')
param location string = resourceGroup().location

@description('Number of worker pool for App Service.')
@minValue(1)
@maxValue(10)
param workerPool int = 1

@description('Size of the Virtual Machine.')
param vmSize string = 'Standard_B2ms'

@description('Name of frontend subnet.')
param frontendSubnet string = 'frontend'

@description('Name of backend subnet.')
param backendSubnet string = 'backend'

@description('Name of gateway subnet.')
param gatewaySubnet string = 'GatewaySubnet'

var location_var = location
var vnetName = '${stackName}-vnet'
var databaseName = 'appdb'
var databaseEdition = 'Basic'
var databaseCollation = 'SQL_Latin1_General_CP1_CI_AS'
var databaseServiceObjectiveName = 'Basic'
var workerPool_var = workerPool
var numberOfWorkersFromWorkerPool = 1
var nicName = '${stackName}vmnic'
var privateDbEndpointName = '${stackName}pvenp'
var privateDbDnsZoneName_var = privateDbDnsZoneName
var privateDbDnsGroupName = '${privateDbEndpointName}/mydnsgroupname'
var privateHost1DnsZoneName = '${stackName}.appserviceenvironment.net'
var gatewayPublicIPName = '${stackName}gwpip'
var gatewayName = '${stackName}gw'
var vpnClientAddressPoolPrefix = '172.15.0.0/24'
var vmName = substring(stackName, 0, 10)
var loginUser_var = substring(loginUser, 0, 8)

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: location_var
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.0.0/16'
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
    subnets: [
      {
        name: frontendSubnet
        properties: {
          addressPrefix: '172.16.0.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: backendSubnet
        properties: {
          addressPrefix: '172.16.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: gatewaySubnet
        properties: {
          addressPrefix: '172.16.255.0/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource vnetName_frontendSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  parent: vnet
  name: frontendSubnet
  properties: {
    addressPrefix: '172.16.0.0/24'
    serviceEndpoints: [
      {
        service: 'Microsoft.Sql'
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
}

resource vnetName_backendSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  parent: vnet
  name: backendSubnet
  properties: {
    addressPrefix: '172.16.1.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
}

resource vnetName_gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  parent: vnet
  name: gatewaySubnet
  properties: {
    addressPrefix: '172.16.255.0/27'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
}

resource stack 'Microsoft.Web/hostingEnvironments@2020-06-01' = {
  name: stackName
  kind: 'ASEV2'
  location: location_var
  properties: {
    internalLoadBalancingMode: 3
    virtualNetwork: {
      id: vnetName_frontendSubnet.id
    }
  }
  dependsOn: [
    vnet

  ]
}

resource Microsoft_Sql_servers_stack 'Microsoft.Sql/servers@2020-08-01-preview' = {
  name: stackName
  location: location_var
  tags: {
    displayName: 'SqlServer'
  }
  properties: {
    administratorLogin: loginUser_var
    administratorLoginPassword: loginPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
  }
  dependsOn: [
    vnet
    vnetName_frontendSubnet
  ]
}

resource stackName_database 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  parent: Microsoft_Sql_servers_stack
  name: databaseName
  location: location_var
  tags: {
    displayName: 'Database'
  }
  sku: {
    name: databaseEdition
    tier: databaseEdition
    capacity: 5
  }
  properties: {
    edition: databaseEdition
    collation: databaseCollation
    requestedServiceObjectiveName: databaseServiceObjectiveName
  }
  dependsOn: [
    stackName
  ]
}

resource stackName_databaseName_current 'Microsoft.Sql/servers/databases/transparentDataEncryption@2017-03-01-preview' = {
  parent: stackName_database
  name: 'current'
  properties: {
    status: 'Enabled'
  }
}

resource stackName_AllowAllMicrosoftAzureIps 'Microsoft.Sql/servers/firewallrules@2020-08-01-preview' = {
  parent: Microsoft_Sql_servers_stack
  name: 'AllowAllMicrosoftAzureIps'
  location: location_var
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
  dependsOn: [stack]
}

resource stackName_allow_frontendSubnet 'Microsoft.Sql/servers/virtualNetworkRules@2020-08-01-preview' = {
  parent: Microsoft_Sql_servers_stack
  name: 'allow-${frontendSubnet}'
  properties: {
    virtualNetworkSubnetId: vnetName_frontendSubnet.id
    ignoreMissingVnetServiceEndpoint: false
  }
}

resource stackName_activeDirectory 'Microsoft.Sql/servers/administrators@2020-08-01-preview' = {
  parent: Microsoft_Sql_servers_stack
  name: 'activeDirectory'
  location: location_var
  properties: {
    administratorType: 'ActiveDirectory'
    login: aadUsername
    sid: aadUserObjectId
    tenantId: subscription().tenantId
  }
}

resource Microsoft_KeyVault_vaults_stack 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: stackName
  location: location_var
  properties: {
    enableRbacAuthorization: false
    enableSoftDelete: false
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: aadUserObjectId
        permissions: {
          secrets: [
            'list'
            'get'
            'set'
          ]
        }
      }
      {
        tenantId: reference(Microsoft_Web_sites_stack.id, '2018-02-01', 'Full').identity.tenantId
        objectId: reference(Microsoft_Web_sites_stack.id, '2018-02-01', 'Full').identity.principalId
        permissions: {
          secrets: [
            'list'
            'get'
            'set'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource Microsoft_Web_serverfarms_stack 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: stackName
  location: location_var
  properties: {
    name: stackName
    hostingEnvironmentProfile: {
      id: stack.id
    }
  }
  sku: {
    name: 'I${workerPool_var}'
    tier: 'Isolated'
    size: 'I${workerPool_var}'
    family: 'I'
    capacity: numberOfWorkersFromWorkerPool
  }
}

resource Microsoft_Web_sites_stack 'Microsoft.Web/sites@2020-06-01' = {
  name: stackName
  location: location_var
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    name: stackName
    serverFarmId: Microsoft_Web_serverfarms_stack.id
    hostingEnvironmentProfile: {
      id: stack.id
    }
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(microsoft_insights_components_stack.id, '2018-05-01-preview').InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'default'
        }
        {
          name: 'DiagnosticServices_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'APPINSIGHTS_PROFILERFEATURE_VERSION'
          value: 'disabled'
        }
        {
          name: 'APPINSIGHTS_SNAPSHOTFEATURE_VERSION'
          value: 'disabled'
        }
        {
          name: 'InstrumentationEngine_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'SnapshotDebugger_EXTENSION_VERSION'
          value: 'disabled'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_BaseExtensions'
          value: 'disabled'
        }
      ]
    }
  }
}

resource stackName_web 'Microsoft.Web/sites/config@2020-06-01' = {
  parent: Microsoft_Web_sites_stack
  name: 'web'
  location: location_var
  properties: {
    netFrameworkVersion: 'v5.0'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: nicName
  location: location_var
  properties: {
    ipConfigurations: [
      {
        name: '${stackName}vmip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetName_backendSubnet.id
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
  location: location_var
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmName}vm'
      adminUsername: loginUser_var
      adminPassword: loginPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter-Core-smalldisk'
        version: 'latest'
      }
      osDisk: {
        name: '${stackName}vmdisk'
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

resource vmName_Antimalware 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'Antimalware'
  location: location_var
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      AntimalwareEnabled: 'true'
      Exclusions: {
        Extensions: '.log;.ldf'
        Paths: 'D:\\IISlogs;D:\\DatabaseLogs'
        Processes: 'mssence.svc'
      }
      RealtimeProtectionEnabled: 'true'
      ScheduledScanSettings: {
        isEnabled: 'true'
        scanType: 'Quick'
        day: 7
        time: 120
      }
    }
  }
}

resource privateDbEndpoint 'Microsoft.Network/privateEndpoints@2019-04-01' = {
  name: privateDbEndpointName
  location: location_var
  properties: {
    subnet: {
      id: vnetName_backendSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: privateDbEndpointName
        properties: {
          privateLinkServiceId: Microsoft_Sql_servers_stack.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet

  ]
}

resource privateDbDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDbDnsZoneName_var
  location: 'global'
  dependsOn: [
    vnet
  ]
}

resource privateDbDnsZoneName_privateDbDnsZoneName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDbDnsZone
  name: '${privateDbDnsZoneName_var}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateDbDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-03-01' = {
  name: privateDbDnsGroupName
  location: location_var
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDbDnsZone.id
        }
      }
    ]
  }
  dependsOn: [

    privateDbEndpoint
  ]
}

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: gatewayPublicIPName
  location: location_var
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2019-04-01' = {
  name: gatewayName
  location: location_var
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetName_gatewaySubnet.id
          }
          publicIPAddress: {
            id: gatewayPublicIP.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: 'Basic'
      tier: 'Basic'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: 'false'
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPoolPrefix
        ]
      }
      vpnClientRootCertificates: [
        {
          name: 'P2SRootCert'
          properties: {
            publicCertData: p2sRootCert
          }
        }
      ]
    }
  }
  dependsOn: [

    vnet
  ]
}

resource Microsoft_Storage_storageAccounts_stack 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: stackName
  location: location_var
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource stackName_default_scripts 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${stackName}/default/scripts'
  dependsOn: [
    stackName
  ]
}

resource privateHost1DnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateHost1DnsZoneName
  location: 'global'
  dependsOn: [
    vnet
  ]
}

resource privateHost1DnsZoneName_privateHost1DnsZoneName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateHost1DnsZone
  name: '${privateHost1DnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource microsoft_insights_components_stack 'microsoft.insights/components@2020-02-02-preview' = {
  name: stackName
  location: location_var
  properties: {
    ApplicationId: stackName
  }
}

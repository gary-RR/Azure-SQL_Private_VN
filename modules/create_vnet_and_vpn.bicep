param vneName string = 'private_azure_sql_vnet1'
param location string=resourceGroup().location
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
    subnets: [
      {
        name: 'sub1'
        properties: {
          addressPrefix:  '10.0.0.0/24'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix:  '10.0.2.0/24'
        }
      }
    ]
  }
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
            id: vnet.properties.subnets[1].id //virtualNetworks_pocvnet_name_GatewaySubnet.id 
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
// resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
//   name: 'ostadstorage'
//   location: location
//   kind: 'StorageV2'
//   sku: {
//     name:  'Standard_GRS'
//   }
// }


output vnetSubnetID string=vnet.properties.subnets[0].id
output vnetId string = vnet.id
output gatewayId string = vpnGateway.id


param location string=resourceGroup().location
param vnetName string = 'private_azure_sql_vnet1'

@description('A unique suffix to add to resource names that need to be globally unique.')
@maxLength(13)
param resourceNameSuffix string = uniqueString(resourceGroup().id)

@allowed( [
  'yes' 
  'no'
])
param createGateway string='yes'

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
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'frontendSubnet'
        properties: {
          addressPrefix:  '10.0.0.0/24'
        }        
      }
      {
        name: 'backendSubnet'
        properties: {
          addressPrefix:  '10.0.1.0/24'
        }
      }
      {
        name: 'gatewaySubnet'
        properties: {
          addressPrefix:  '10.0.2.0/24'
        }
      }
    ]
  }
}


resource publicIPAddresses_pocgtway1_name_rsc 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'gatewayPublicIP'
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

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-05-01' = if(createGateway=='yes') {
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
            id: vnet.properties.subnets[2].id //gatewaySubnet.id 
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


output frontendSubnet object= vnet.properties.subnets[0]
output backendSubnet object=vnet.properties.subnets[1] 
output gatewaySubnet object=vnet.properties.subnets[2] 
output vnetId string = vnet.id
output gatewayId string = ((createGateway=='yes') ? vpnGateway.id : '') 


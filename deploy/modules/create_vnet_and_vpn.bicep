@description('mnnn')
param location string=resourceGroup().location
param appName string='cosmo'

@allowed( [
  'yes' 
  'no'
])
param createGateway string='yes'

param vnetAddressPrefixes string='10.0.0.0/16'
param subnet1AddressPrefixes string='10.0.0.0/24'
param subnet2AddressPrefixes string='10.0.1.0/24'
param subnet3AddressPrefixes string='10.0.2.0/24'
param vpnClientAddressPrefix string='172.16.201.0/24'

var tenanatID=subscription().tenantId
// The following returns "https://login.microsoftonline.com" which is a best practice raher hard coding it
var aadTenantURL=environment().authentication.loginEndpoint
var aadTenant='${aadTenantURL}${tenanatID}'

var aadIssuer='https://sts.windows.net/${tenanatID}/'

// Audience: The Application ID of the "Azure VPN" Microsoft Entra Enterprise App.
// Azure Public: 41b23e61-6c1e-4545-b367-cd054e0ed4b4
// Azure Government: 51bb15d4-3a4f-4ebf-9dca-40096fe32426
// Azure Germany: 538ee9e6-310a-468d-afef-ea97365856a9
// Microsoft Azure operated by 21Vianet: 49f817b6-84ae-4cc0-928c-73f27289b3aa
var aadAudience='41b23e61-6c1e-4545-b367-cd054e0ed4b4'

var resourceNameSuffix=uniqueString(resourceGroup().id)
var vnetName= 'vnet-${appName}-${resourceNameSuffix}'
var subnet1Name='frontendSubnet'
var subnet2Name='backendSubnet'
var subnet3Name='gatewaySubnet'
var gatewayPublicIPName='pip-gateway-${appName}-${resourceNameSuffix}'
var vpnName='vpn-${appName}-${resourceNameSuffix}'

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefixes
      ]
    }
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix:  subnet1AddressPrefixes
        }        
      }
      {
        name: subnet2Name
        properties: {
          addressPrefix:  subnet2AddressPrefixes
        }
      }
      {
        name: subnet3Name
        properties: {
          addressPrefix:  subnet3AddressPrefixes
        }
      }
    ]
  }
}


resource gatewayPublicAddress 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: gatewayPublicIPName
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
  name: vpnName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        // id: resourceId(rg, 'Microsoft.Network/virtualNetworkGateways/ipConfigurations', vpnGateway.name ,'default')
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: gatewayPublicAddress.id
          }
          subnet: {
            id: vnet.properties.subnets[2].id 
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
          vpnClientAddressPrefix 
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


output frontendSubnet string= parseCidr(vnet.properties.subnets[0].properties.addressPrefix).firstUsable
output backendSubnet object=vnet.properties.subnets[1] 
output gatewaySubnet object=vnet.properties.subnets[2] 
output vnetId string=vnet.id
output gatewayId string = ((createGateway=='yes') ? vpnGateway.id : '') 
output test string='/subscriptionsnnnfvhfdggfshghtrwssdfghhgdddffggfffewssssssyyff'


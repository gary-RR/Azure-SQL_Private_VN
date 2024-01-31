@maxLength(63)
param privateDnsZoneName string='sqlPrivateDnsZone'
param location string=resourceGroup().location

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: location
  properties: {}
}

output privateDnsZoneId string=privateDnsZone.id

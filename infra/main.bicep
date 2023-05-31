targetScope = 'subscription'

// The main bicep module to provision Azure resources.
// For a more complete walkthrough to understand how this file works with azd,
// see https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/make-azd-compatible?pivots=azd-create

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('The Microsoft AAD app client ID for the bot.')
param botAadAppClientId string

@secure()
@description('The Microsoft AAD app client secret for the bot.')
param botAadAppClientSecret string

@maxLength(42)
@description('The display name for the bot that shows up in Teams.')
param botDisplayName string

// Optional parameters to override the default azd resource naming conventions.
// Add the following to main.parameters.json to provide values:
// "resourceGroupName": {
//      "value": "myGroupName"
// }
param resourceGroupName string = ''

var abbrs = loadJsonContent('./abbreviations.json')

// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
}

// Generate a unique token to be used in naming resources.
// Remove linter suppression after using.
#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Name of the service defined in azure.yaml
// A tag named azd-service-name with this value should be applied to the service host resource, such as:
//   Microsoft.Web/sites for appservice, function
// Example usage:
//   tags: union(tags, { 'azd-service-name': apiServiceName })
#disable-next-line no-unused-vars
var apiServiceName = 'bot-api'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module appserviceplan './host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: 'appserviceplan-${environmentName}-${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B1'
    }
  }
}

module appservice './host/appservice.bicep' = {
  name: 'appservice'
  scope: rg
  params: {
    name: 'appservice-${environmentName}-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'bot-api' })
    appServicePlanId: appserviceplan.outputs.id
    runtimeName: 'node'
    runtimeVersion: '16-lts'
    alwaysOn: true
    ftpsState: 'FtpsOnly'
  }
}

module webAppSettings './host/appservice-appsettings.bicep' = {
  name: 'appservice-appsettings'
  scope: rg
  params: {
    name: appservice.outputs.name    
    appSettings: {
      BOT_ID: botAadAppClientId
      BOT_PASSWORD: botAadAppClientSecret
    }
  }
}

// The bot service
module bot './bot/botservice.bicep' = {
  name: 'bot'
  scope: rg
  params: {
    name: 'botservice-${environmentName}-${resourceToken}'
    location: location
    tags: tags
    botAadAppClientId: botAadAppClientId
    botAppDomain: appservice.outputs.uri
    botDisplayName: botDisplayName
  }
}



// Add outputs from the deployment here, if needed.
//
// This allows the outputs to be referenced by other bicep deployments in the deployment pipeline,
// or by the local machine as a way to reference created resources in Azure for local development.
// Secrets should not be added here.
//
// Outputs are automatically saved in the local azd environment .env file.
// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId

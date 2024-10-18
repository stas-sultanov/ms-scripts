Authored by Stas Sultanov [ [linkedIn](https://www.linkedin.com/in/stas-sultanov) | [gitHub](https://github.com/stas-sultanov) ]

# About

The Powershell module to  for Microsoft Power Platform.

## Purpose

The module has been developed with the purpose to be used for automated management of Power Platform Environments.

## Licensing

The module is developed exclusively by Stas Sultanov and is distributed under the MIT license.

# Functions

The following functions are implemented.

| Area              | Name                               | Description
| ---               | ----                               | ----
| BusinessUnits     | BusinessUnit.GetRootId             | Get Id of the root Business Unit within the Power Platform Environment.
| Environments      | Environment.Create                 | Create an environment within the Power Platform tenant.
| Environments      | Environment.Delete                 | Delete an environment from the Power Platform tenant.
| Environments      | Environment.Retrieve               | Retrieve an environment info.
| Environments      | Environment.RetrieveAll            | Retrieve information about all accessible environments.
| Environments      | Environment.Update                 | Update an environment within the Power Platform tenant.
| ManagedIdentities | ManagedIdentity.CreateIfNotExist   | Create a Managed Identity within the Power Platform Environment.
| ManagedIdentities | ManagedIdentity.DeleteIfExist      | Delete a Managed Identity from the Power Platform environment.
| PluginAssemblies  | PluginAssembly.BindManagedIdentity | Bind the Plugin Assembly with the Managed Identity.
| SystemUsers       | SystemUser.AssociateRoles          | Associate roles to the System User.
| SystemUsers       | SystemUser.CreateIfNotExist        | Create a System User within the Power Platform Environment.
| SystemUsers       | SystemUser.DeleteIfExist           | Delete a System User from the Power Platform environment.

# Use

## Import

To start using the module, the following code must be executed to import the module.

```powershell
Import-Module '.\PowerPlatform.psd1' -Force;
```

## Authentication and Authorization

Each function has the 'accessToken' parameter.
The token is used to authorize access in Power Platform.
Pay attention that functions has different requirements to the AUD of the token.
To get the token following Powershell code with AZ module may be used.
Note: replace '[AUD]' with value from the function description.

```powershell
$accessToken = (Get-AzAccessToken -ResourceUrl '[AUD]' -AsSecureString).Token;
```
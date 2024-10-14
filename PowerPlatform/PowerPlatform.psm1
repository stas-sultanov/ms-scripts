using namespace System;
using namespace Microsoft.PowerShell.Commands;

<# ######################################## #>
<# Functions to manage Managed Environments #>
<# ######################################## #>

class PowerPlatformEnvironmentInfo
{
	[ValidateNotNullOrEmpty()]
	[String] $azureLocation

	[ValidateNotNullOrEmpty()]
	[String] $domainName

	[ValidateNotNullOrEmpty()]
	[String] $name

	[ValidateNotNullOrEmpty()]
	[String] $url
}

$EnvironmentApiUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform';

$EnvironmentSelect = '$select=properties.linkedEnvironmentMetadata.instanceUrl,properties.azureRegion,properties.linkedEnvironmentMetadata.domainName,name';

function PowerPlatform.Environment.Create
{
	<#
	.SYNOPSIS
		Create an environment within the Power Platform tenant.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER settings
		Object that contains all settings required to create an environment.
	.OUTPUTS
		Short information about the environment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([PowerPlatformEnvironmentInfo])]
	param
	(
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[SecureString] $accessToken,

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $false)]
		[String] $apiVersion = '2024-05-01',

		[ValidateNotNull()]
		[Parameter(Mandatory = $true)]
		[Object] $settings
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# invoke request to create environment and wait for result
		$response = InvokeRequestAndWaitResult `
			-accessToken $accessToken `
			-body $settings `
			-method Post `
			-uri "$($EnvironmentApiUri)/environments?api-version=$($apiVersion)&retainOnProvisionFailure=false" `
			-Verbose:$isVerbose;

		# get environment name
		$name = ($response.Content | ConvertFrom-Json -AsHashtable).links.environment.path.Split('/')[4];

		# retrieve environment info
		$result = PowerPlatform.Environment.Retrieve `
			-accessToken $accessToken `
			-apiVersion $apiVersion `
			-name $name `
			-Verbose:$isVerbose;

		return $result;
	}
}

function PowerPlatform.Environment.Delete
{
	<#
	.SYNOPSIS
		Delete an environment from the Power Platform tenant.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER name
		Name of the Power Platform environment.
	.OUTPUTS
		True if environment deleted, False otherwise.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([Boolean])]
	param
	(
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[SecureString] $accessToken,

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $false)]
		[String] $apiVersion = '2021-04-01',

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[String] $name
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create requests base uri
		$baseRequestUri = "$($EnvironmentApiUri)/scopes/admin/environments/$($name)";

		# execute validate request
		$validateResponse = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Post `
			-Token $accessToken `
			-Uri "$($baseRequestUri)/validateDelete?api-version=$($apiVersion)" `
			-Verbose:$isVerbose;

		# get validate response content
		$validateResponseContent = $validateResponse.Content | ConvertFrom-Json -AsHashtable;

		# check if can delete
		if (-not $validateResponseContent.canInitiateDelete)
		{
			return $false;
		}

		# make request and wait till complete
		$null = InvokeRequestAndWaitResult `
			-accessToken $accessToken `
			-uri "$($baseRequestUri)?api-version=$($apiVersion)" `
			-method Delete `
			-Verbose:$isVerbose;

		return $true;
	}
}

function PowerPlatform.Environment.Retrieve
{
	<#
	.SYNOPSIS
		Retrieve an environment info.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER name
		Name of the Power Platform environment.
	.OUTPUTS
		Short information about the environment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([PowerPlatformEnvironmentInfo])]
	param
	(
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[SecureString] $accessToken,

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $false)]
		[String] $apiVersion = '2024-05-01',

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[String] $name
	)
	process
	{
		# invoke request to get environment info
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Get `
			-Token $accessToken `
			-Uri "$($EnvironmentApiUri)/scopes/admin/environments/$($name)?api-version=$($apiVersion)&$($EnvironmentSelect)" `
			-Verbose:$isVerbose;

		# convert config response content
		$environment = $response.Content | ConvertFrom-Json -AsHashtable;

		# create result
		$result = [PowerPlatformEnvironmentInfo]@{
			azureLocation = $environment.properties.azureRegion
			domainName    = $environment.properties.linkedEnvironmentMetadata.domainName
			name          = $environment.name
			url           = $environment.properties.linkedEnvironmentMetadata.instanceUrl
		};

		return $result;
	}
}

function PowerPlatform.Environment.RetrieveAll
{
	<#
	.SYNOPSIS
		Retrieve information about all accessible environments.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER settings
		Object that contains all settings required to create an environment.
	.OUTPUTS
		Array of objects that each provides a short information about the environments.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([PowerPlatformEnvironmentInfo[]])]
	param
	(
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[SecureString] $accessToken,

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $false)]
		[String] $apiVersion = '2024-05-01'
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# query existing environments | OData $filter does not work :(
		Write-Verbose("Invoke request to look for existing environment: $existingRequestUri");
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Get `
			-Token $accessToken `
			-Uri "$($EnvironmentApiUri)/scopes/admin/environments?api-version=$($apiVersion)&$($EnvironmentSelect)" `
			-Verbose:$isVerbose;

		# convert content
		$environmentList = ($response.Content | ConvertFrom-Json -AsHashtable).value;

		# convert items
		$result = $environmentList | ForEach-Object {
			[PowerPlatformEnvironmentInfo]@{
				azureLocation = $_.properties.azureRegion
				domainName    = $_.properties.linkedEnvironmentMetadata.domainName
				name          = $_.name
				url           = $_.properties.linkedEnvironmentMetadata.instanceUrl
			}
		};

		return [PowerPlatformEnvironmentInfo[]] $result;
	}
}

function PowerPlatform.Environment.Update
{
	<#
	.SYNOPSIS
		Update an environment within the Power Platform tenant.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER name
		Name of the Power Platform environment.
	.PARAMETER settings
		Object that contains all settings required to update an environment.
	.OUTPUTS
		Short information about the environment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([PowerPlatformEnvironmentInfo])]
	param
	(
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[SecureString] $accessToken,

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $false)]
		[String] $apiVersion = '2024-05-01',

		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		[String] $name,

		[ValidateNotNull()]
		[Parameter(Mandatory = $true)]
		[Object] $settings
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];
		
		# make request and wait till complete
		$null = InvokeRequestAndWaitResult `
			-accessToken $accessToken `
			-body $settings `
			-uri "$($EnvironmentApiUri)/scopes/admin/environments/$($name)?api-version=$($apiVersion)" `
			-method Patch `
			-Verbose:$isVerbose;

		# retrieve environment info
		$result = PowerPlatform.Environment.Retrieve `
			-accessToken $accessToken `
			-apiVersion $apiVersion `
			-name $name `
			-Verbose:$isVerbose;

		return $result;
	}
}

<# ###################################### #>
<# Functions to manage Managed Identities #>
<# ###################################### #>

function PowerPlatform.ManagedIdentity.Provision
{
	<#
	.SYNOPSIS
		Provision a Managed Identity within the Power Platform Environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/managedidentity
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER applicationId
		Application (Client) Id of the Service Principal within the Entra tenant.
	.PARAMETER id
		Id of the Managed Identity within Power Platform Environment.
	.PARAMETER instanceUrl
		Url of the Power Platform environment.
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER tenantId
		Id of the Entra tenant.
	.OUTPUTS
		System.Object
			id : Environment Id
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([ordered])]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $true)]  [String]       $applicationId,
		[Parameter(Mandatory = $false)] [String]       $id = (New-Guid).Guid,
		[Parameter(Mandatory = $true)]  [String]       $instanceUrl,
		[Parameter(Mandatory = $true)]  [String]       $tenantId
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create request uri
		$requestUri = "$($instanceUrl)api/data/$($apiVersion)/managedidentities";

		# create request body
		$requestBody = @{
			applicationid     = $applicationId
			credentialsource  = 2
			managedidentityid = $id
			subjectscope      = 1
			tenantid          = $tenantId
		};

		# make request
		$response = InvokeRequestAndWaitResult `
			-accessToken $accessToken `
			-body $requestBody `
			-method Post `
			-uri $requestUri `
			-Verbose:$isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

		# create result from response
		$result = [ordered]@{
			id = $responseContent.managedidentityid
		};

		# return result
		return $result;
	}
}

function PowerPlatform.ManagedIdentity.Remove
{
	<#
	.SYNOPSIS
		Remove a Managed Identity from the Power Platform environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/managedidentity
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER id
		Id of the Managed Identity within the Power Platform Environment.
	.PARAMETER instanceUrl
		Url of the Power Platform environment.
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $true)]  [String]       $id,
		[Parameter(Mandatory = $true)]  [String]       $instanceUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create request uri
		$requestUri = "$($instanceUrl)api/data/$($apiVersion)/managedidentities($($id))";

		# execute request
		$null = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:$isVerbose;
	}
}

function PowerPlatform.SystemUser.Provision
{
	<#
	.SYNOPSIS
		Provision a System User within the Power Platform Environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/systemuser
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER applicationId
		Application (Client) Id of the Service Principal within the Entra tenant.
	.PARAMETER businessUnitId
		Unique identifier of the Business Unit with which the User is associated.
		If not specified root business unit will be used.
	.PARAMETER instanceUrl
		Url of the Power Platform Environment.
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'
	.OUTPUTS
		System.Object
			id : System User Id
			roleIds : collection of Ids of assigned Roles
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([ordered])]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[Parameter(Mandatory = $true)]  [String]       $applicationId,
		[Parameter(Mandatory = $false)] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $false)] [String]       $businessUnitId = $null,
		[Parameter(Mandatory = $true)]  [String]       $instanceUrl,
		[Parameter(Mandatory = $true)]  [String[]]     $roleIds
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# check if business unit is specified
		if ([String]::IsNullOrEmpty($businessUnitId))
		{
			# create request uri to get root business unit
			$requestUri = "$($instanceUrl)api/data/$($apiVersion)/businessunits?%24select=businessunitid&%24filter=_parentbusinessunitid_value%20eq%20null";

			# execute request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
				-Method Get `
				-Token $accessToken `
				-Uri $requestUri `
				-Verbose:$isVerbose;

			# convert response content
			$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

			# set business unit id
			$businessUnitId = $responseContent.Value[0].businessunitid;
		}

		# create request uri
		$requestUri = "$($instanceUrl)api/data/$($apiVersion)/systemusers";

		# create request body
		$requestBody = [PSCustomObject]@{
			accessmode                  = 4
			'businessunitid@odata.bind' = "/businessunits($businessUnitId)"
			applicationid               = $applicationId
			isdisabled                  = $false
		};

		# make request
		$response = InvokeRequestAndWaitResult `
			-accessToken $accessToken `
			-body $requestBody `
			-method Post `
			-uri $requestUri `
			-Verbose:$isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;
		
		# create result from response
		$result = @{
			id      = $responseContent.systemuserid
			roleIds = [System.Collections.Generic.List[String]]::new()
		};

		# assign roles
		foreach ($roleId in $roleIds)
		{
			# create request uri
			$requestUri = "$($instanceUrl)api/data/$($apiVersion)/systemusers($($result.id))%2Fsystemuserroles_association%2F%24ref";

			# create request body
			$requestBody = [PSCustomObject]@{
				'@odata.id' = "$($instanceUrl)api/data/$($apiVersion)/roles($($roleId))"
			} | ConvertTo-Json -Compress;

			# execute request
			$null = Invoke-WebRequest `
				-Authentication Bearer `
				-Body $requestBody `
				-ContentType 'application/json' `
				-Method Post `
				-Token $accessToken `
				-Uri $requestUri `
				-Verbose:$isVerbose;

			$result.roleIds.Add($roleId);
		}

		# return result
		return $result;
	}
}

<# ################################ #>
<# Functions to manage System Users #>
<# ################################ #>

function PowerPlatform.SystemUser.Remove
{
	<#
	.SYNOPSIS
		Remove a System User from the Power Platform environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/systemuser
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER id
		Id of the System User within the Power Platform Environment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $true)]  [String]       $id,
		[Parameter(Mandatory = $true)]  [String]       $instanceUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create request uri
		$requestUri = "$($instanceUrl)api/data/$($apiVersion)/systemusers($($id))";

		# execute disable request
		$null = InvokeRequestAndWaitResult `
			-accessToken $accessToken `
			-body @{ isdisabled = $true } `
			-method Patch `
			-uri $requestUri `
			-Verbose:$isVerbose;

		# execute delete request
		# this request changes state to deleted
		$null = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:$isVerbose;

		# execute delete request
		# this is actual delete
		$null = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:$isVerbose;
	}
}

<# ######################### #>
<# Internal helper functions #>
<# ######################### #>

function InvokeRequestAndWaitResult
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString]     $accessToken,
		[Parameter(Mandatory = $false)] [Object]           $body = $null,
		[Parameter(Mandatory = $true)]  [WebRequestMethod] $method,
		[Parameter(Mandatory = $true)]  [String]           $uri
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		$response = $null;

		if ($null -eq $body)
		{
			# execute request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
				-Method $method `
				-Token $accessToken `
				-Uri $uri `
				-Verbose:$isVerbose;
		}
		else
		{
			$requestBody = $body | ConvertTo-Json -Compress -Depth 100;

			# execute request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
				-Body $requestBody `
				-ContentType 'application/json' `
				-Method $method `
				-Token $accessToken `
				-Uri $uri `
				-Verbose:$isVerbose;
		}

		if (!$response.Headers.ContainsKey('Location'))
		{
			return $response;
		}

		# get status uri
		$statusUri = $response.Headers['Location'][0];

		while ($true)
		{
			# make status request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
				-Method Get `
				-Token $accessToken `
				-Uri $statusUri `
				-Verbose:$isVerbose;

			if (!$response.Headers.ContainsKey('Retry-After'))
			{
				break;
			}

			# get amount of seconds to sleep
			$retryAfter = [Int32] $response.Headers['Retry-After'][0];

			# fall sleep
			Start-Sleep -s $retryAfter;
		}

		# return response
		return $response;
	}
}
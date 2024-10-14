using namespace System;
using namespace Microsoft.PowerShell.Commands;

function PowerPlatform.Environment.Provision
{
	<#
	.SYNOPSIS
		Provision an environment within the Power Platform tenant.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
		Routine assumes that domainName is a unieque identifier of the environment.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER settings
		Object that contains all settings required to create an environment.
	.OUTPUTS
		[OrderedDictionary]
		On object with following fields:
			- azureRegion [System.String]
			- domainName  [System.String]
			- instanceUrl [System.String]
			- name        [System.String]
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[OutputType([ordered])]
	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[parameter(Mandatory = $false)] [string]       $apiVersion = '2024-05-01',
		[Parameter(Mandatory = $true)]  [Object]       $settings
	)
	process
	{
		$baseRequestUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform';
		$requestSelect = '$select=properties.linkedEnvironmentMetadata.instanceUrl,properties.azureRegion,properties.linkedEnvironmentMetadata.domainName,name';

		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# query existing environments | odata $filter does not work :(
		Write-Verbose("Invoke request to look for existing environment: $existingRequestUri");
		$existingResponse = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Get `
			-Token $accessToken `
			-Uri "$($baseRequestUri)/scopes/admin/environments?api-version=$($apiVersion)&$($requestSelect)" `
			-Verbose:$isVerbose;

		# filter by domain name
		$existingEnvironmentList = ($existingResponse.Content | ConvertFrom-Json -AsHashtable).value;

		# try find environment with same domainName
		$environment = $existingEnvironmentList | Where-Object { $_.properties.linkedEnvironmentMetadata.domainName -eq $settings.properties.linkedEnvironmentMetadata.domainName };

		# check if environment found
		if ($null -eq $environment)
		{
			# invoke request to create environment and wait for result
			$createResponse = InvokeRequestAndWaitResult `
				-accessToken $accessToken `
				-body $settings `
				-method Post `
				-uri "$($baseRequestUri)/environments?api-version=$($apiVersion)&retainOnProvisionFailure=false" `
				-Verbose:$isVerbose;

			# get environment name
			$environmentName = ($createResponse.Content | ConvertFrom-Json -AsHashtable).links.environment.path.Split('/')[4];

			# invoke request to get environment configuration
			$configResponse = Invoke-WebRequest `
				-Authentication Bearer `
				-Method Get `
				-Token $accessToken `
				-Uri "$($baseRequestUri)/scopes/admin/environments/$($environmentName)?api-version=$($apiVersion)&$($requestSelect)" `
				-Verbose:$isVerbose;

			# convert config response content
			$environment = $configResponse.Content | ConvertFrom-Json -AsHashtable;
		}
		else
		{
			Write-Verbose('Invoke request to patch environment and wait for result.');
		}

		# create projection and return as result
		return [ordered]@{
			azureRegion = $environment.properties.azureRegion
			domainName  = $environment.properties.linkedEnvironmentMetadata.domainName
			instanceUrl = $environment.properties.linkedEnvironmentMetadata.instanceUrl
			name        = $environment.name
		};
	}
}

function PowerPlatform.Environment.Remove
{
	<#
	.SYNOPSIS
		Remove an environment from the Power Platform tenant.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER environmentName
		Name of the Power Platform environment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[parameter(Mandatory = $false)] [string]       $apiVersion = '2021-04-01',
		[Parameter(Mandatory = $true)]  [String]       $environmentName
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		$baseUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments';

		# create request uri to validate delete
		$validateRequestUri = "$($baseUri)/$($environmentName)/validateDelete?api-version=$($apiVersion)";

		# execute validate request
		$validateResponse = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Post `
			-Token $accessToken `
			-Uri $validateRequestUri `
			-Verbose:$isVerbose;

		# get validate response content
		$validateResponseContent = $validateResponse.Content | ConvertFrom-Json -AsHashtable;

		# check if can delete
		if (-not $validateResponseContent.canInitiateDelete)
		{
			return 'can not delete';
		}
		
		# create request uri to delete
		$requestUri = "$($baseUri)/$($environmentName)?api-version=$($apiVersion)";

		# make request and wait till complete
		$null = InvokeRequestAndWaitResult `
			-accessToken $accessToken `
			-uri $requestUri `
			-method Delete `
			-Verbose:$isVerbose;
	}
}

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

	[OutputType([ordered])]
	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
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
		Id of the Managed Identity within the Power Platform Enviornment.
	.PARAMETER instanceUrl
		Url of the Power Platform environment.
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
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

	[OutputType([ordered])]
	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
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

function PowerPlatform.SystemUser.Remove
{
	<#
	.SYNOPSIS
		Remove a Sysetm User from the Power Platform environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/systemuser
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER id
		Id of the System User within the Power Platform Enviornment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
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

<# this is an internal helper function #>
function InvokeRequestAndWaitResult
{
	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]  [SecureString]     $accessToken,
		[Parameter(Mandatory = $false)] [Object]           $body = $null,
		[Parameter(Mandatory = $true)]  [WebRequestMethod] $method,
		[Parameter(Mandatory = $true)]  [String]           $uri
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		$response = $null;

		if (($method -eq 'Patch') -or ($method -eq 'Post') -or ($method -eq 'Put'))
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
		else
		{
			# execute request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
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
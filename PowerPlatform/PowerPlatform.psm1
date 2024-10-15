using namespace System;
using namespace Microsoft.PowerShell.Commands;

<# ################################ #>
<# Functions to manage Environments #>
<# ################################ #>

class PowerPlatformEnvironmentInfo
{
	[ValidateNotNullOrEmpty()] [String] $azureLocation

	[ValidateNotNullOrEmpty()] [String] $domainName

	[ValidateNotNullOrEmpty()] [String] $name

	[ValidateNotNullOrEmpty()] [Uri]    $url
}

$EnvironmentApiUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform';

$EnvironmentSelect = '$select=properties.linkedEnvironmentMetadata.instanceUrl,properties.azureRegion,properties.linkedEnvironmentMetadata.domainName,name';

function PowerPlatform.Environment.Create
{
	<#
	.SYNOPSIS
		Create an environment within the Power Platform tenant.
	.DESCRIPTION
		Can be executed by an Identity that has Power Platform Administrator role within Entra.
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
		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $false)] [String]       $apiVersion = '2024-05-01',

		[ValidateNotNull()]        [Parameter(Mandatory = $true)]  [Object]       $settings
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create web request uri
		$uri = "$($EnvironmentApiUri)/environments?api-version=$($apiVersion)&retainOnProvisionFailure=false";

		# invoke web request to create environment and get to completion
		$response = InvokeWebRequestAndGetComplete -accessToken $accessToken -body $settings -method Post -uri $uri -Verbose:$isVerbose;

		# get environment name
		$name = ($response.Content | ConvertFrom-Json -AsHashtable).links.environment.path.Split('/')[4];

		# retrieve environment info
		$result = PowerPlatform.Environment.Retrieve -accessToken $accessToken -apiVersion $apiVersion -name $name -Verbose:$isVerbose;

		return $result;
	}
}

function PowerPlatform.Environment.Delete
{
	<#
	.SYNOPSIS
		Delete an environment from the Power Platform tenant.
	.DESCRIPTION
		Can be executed by an Identity that has Power Platform Administrator role within Entra.
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
		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $false)] [String]       $apiVersion = '2021-04-01',

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $name
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create requests base uri
		$baseRequestUri = "$($EnvironmentApiUri)/scopes/admin/environments/$($name)";

		# create validation web request uri
		$validateUri = "$($baseRequestUri)/validateDelete?api-version=$($apiVersion)";

		# invoke web request to validate deletion
		$validateResponse = InvokeWebRequest -accessToken $accessToken -method Post -uri $validateUri -Verbose:$isVerbose;

		# get validation response content
		$validateResponseContent = $validateResponse.Content | ConvertFrom-Json -AsHashtable;

		# check if can delete
		if (-not $validateResponseContent.canInitiateDelete)
		{
			return $false;
		}

		# create deletion web request uri
		$deleteUri = "$($baseRequestUri)?api-version=$($apiVersion)";

		# invoke web request to delete and get to completion
		$null = InvokeWebRequestAndGetComplete -accessToken $accessToken -method Delete -uri $deleteUri -Verbose:$isVerbose;

		return $true;
	}
}

function PowerPlatform.Environment.Retrieve
{
	<#
	.SYNOPSIS
		Retrieve an environment info.
	.DESCRIPTION
		Can be executed by an Identity that has Power Platform Administrator role within Entra.
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
		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $false)] [String]       $apiVersion = '2024-05-01',

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $name
	)
	process
	{
		# create web request uri
		$uri = "$($EnvironmentApiUri)/scopes/admin/environments/$($name)?api-version=$($apiVersion)&$($EnvironmentSelect)";

		# invoke web request to get environment info
		$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $uri -Verbose:$isVerbose;

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
		Can be executed by an Identity that has Power Platform Administrator role within Entra.
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
		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $false)] [String]       $apiVersion = '2024-05-01'
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create web request uri
		$uri = "$($EnvironmentApiUri)/scopes/admin/environments?api-version=$($apiVersion)&$($EnvironmentSelect)";

		# invoke web request to get all accessible environments | OData $filter does not work :(
		$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $uri -Verbose:$isVerbose;

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
		Can be executed by an Identity that has Power Platform Administrator role within Entra.
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
		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $false)] [String]       $apiVersion = '2024-05-01',

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $name,

		[ValidateNotNull()]        [Parameter(Mandatory = $true)]  [Object]       $settings
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create web request uri
		-uri "$($EnvironmentApiUri)/scopes/admin/environments/$($name)?api-version=$($apiVersion)" `
		
		# invoke web request to update the environment and get to completion
		$null = InvokeWebRequestAndGetComplete -accessToken $accessToken -body $settings -uri $uri -method Patch -Verbose:$isVerbose;

		# retrieve environment info
		$result = PowerPlatform.Environment.Retrieve -accessToken $accessToken -apiVersion $apiVersion -name $name -Verbose:$isVerbose;

		return $result;
	}
}

<# ###################################### #>
<# Functions to manage Managed Identities #>
<# ###################################### #>

function PowerPlatform.ManagedIdentity.CreateIfNotExist
{
	<#
	.SYNOPSIS
		Create a Managed Identity within the Power Platform Environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/managedidentity
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER applicationId
		Application (Client) Id of the Service Principal within the Entra tenant.
	.PARAMETER environmentUrl
		Url of the Power Platform environment.
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER id
		Id of the Managed Identity within Power Platform Environment.
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
		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $false)] [String]       $apiVersion = 'v9.2',

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $applicationId,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $environmentUrl,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $id,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $tenantId
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# check if identity exist
		$exist = PowerPlatform.ManagedIdentity.Exist -accessToken $accessToken -apiVersion $apiVersion -environmentUrl $environmentUrl -Verbose:$isVerbose;

		if ($exist)
		{
			return [ordered]@{
				id = $id
			};
		}

		# create web request body
		$body = @{
			applicationid     = $applicationId
			credentialsource  = 2
			managedidentityid = $id
			subjectscope      = 1
			tenantid          = $tenantId
		};

		# create web request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/managedidentities";

		# invoke web request to create managed identity and get to completion
		$response = InvokeWebRequestAndGetComplete -accessToken $accessToken -body $body -method Post -uri $uri -Verbose:$isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

		# create result from response
		$result = [ordered]@{
			id = $responseContent.managedidentityid
		};

		return $result;
	}
}

function PowerPlatform.ManagedIdentity.DeleteIfExist
{
	<#
	.SYNOPSIS
		Delete a Managed Identity from the Power Platform environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/managedidentity
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER id
		Id of the Managed Identity within the Power Platform Environment.
	.PARAMETER environmentUrl
		Url of the Power Platform environment.
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.OUTPUTS
		True if environment deleted, False otherwise.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	[OutputType([Boolean])]
	param
	(
		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $false)] [String]       $apiVersion = 'v9.2',

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $id,

		[ValidateNotNullOrEmpty()] [Parameter(Mandatory = $true)]  [String]       $environmentUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# check if identity exist
		$exist = PowerPlatform.ManagedIdentity.Exist -accessToken $accessToken -apiVersion $apiVersion -environmentUrl $environmentUrl -Verbose:$isVerbose;

		if (!$exist)
		{
			return $false;
		}

		# create web request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/managedidentities($($id))";

		# invoke web request
		$null = InvokeWebRequest -accessToken $accessToken -method Delete -uri $uri -Verbose:$isVerbose;

		return $true;
	}
}

# this is internal helper function
function PowerPlatform.ManagedIdentity.Exist
{
	[CmdletBinding()]
	[OutputType([Boolean])]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString] $accessToken,

		[Parameter(Mandatory = $false)] [String]       $apiVersion = 'v9.2',

		[Parameter(Mandatory = $true)]  [String]       $environmentUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create web request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/managedidentities?`$select=managedidentityid&`$filter=managedidentityid eq $($id)";

		# invoke web request to check if managed identity exist
		$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $uri -Verbose:$isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

		$result = $responseContent.value.Count -eq 1;

		return $result;
	}
}

<# ################################ #>
<# Functions to manage System Users #>
<# ################################ #>

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
	.PARAMETER environmentUrl
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
		[Parameter(Mandatory = $true)]  [String]       $environmentUrl,
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
			$uri = "$($environmentUrl)api/data/$($apiVersion)/businessunits?%24select=businessunitid&%24filter=_parentbusinessunitid_value%20eq%20null";

			# execute request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
				-Method Get `
				-Token $accessToken `
				-Uri $uri `
				-Verbose:$isVerbose;

			# convert response content
			$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

			# set business unit id
			$businessUnitId = $responseContent.Value[0].businessunitid;
		}

		# create request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/systemusers";

		# create request body
		$requestBody = [PSCustomObject]@{
			accessmode                  = 4
			'businessunitid@odata.bind' = "/businessunits($businessUnitId)"
			applicationid               = $applicationId
			isdisabled                  = $false
		};

		# make request
		$response = InvokeWebRequestAndGetComplete `
			-accessToken $accessToken `
			-body $requestBody `
			-method Post `
			-uri $uri `
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
			$uri = "$($environmentUrl)api/data/$($apiVersion)/systemusers($($result.id))%2Fsystemuserroles_association%2F%24ref";

			# create request body
			$requestBody = [PSCustomObject]@{
				'@odata.id' = "$($environmentUrl)api/data/$($apiVersion)/roles($($roleId))"
			} | ConvertTo-Json -Compress;

			# execute request
			$null = Invoke-WebRequest `
				-Authentication Bearer `
				-Body $requestBody `
				-ContentType 'application/json' `
				-Method Post `
				-Token $accessToken `
				-Uri $uri `
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
		[Parameter(Mandatory = $true)]  [String]       $environmentUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/systemusers($($id))";

		# execute disable request
		$null = InvokeWebRequestAndGetComplete `
			-accessToken $accessToken `
			-body @{ isdisabled = $true } `
			-method Patch `
			-uri $uri `
			-Verbose:$isVerbose;

		# execute delete request
		# this request changes state to deleted
		$null = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $uri `
			-Verbose:$isVerbose;

		# execute delete request
		# this is actual delete
		$null = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $uri `
			-Verbose:$isVerbose;
	}
}

<# ######################### #>
<# Internal helper functions #>
<# ######################### #>

function InvokeWebRequest
{
	[CmdletBinding()]
	[OutputType([WebResponseObject])]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString]     $accessToken,
		[Parameter(Mandatory = $false)] [Object]           $body = $null,
		[Parameter(Mandatory = $true)]  [WebRequestMethod] $method,
		[Parameter(Mandatory = $true)]  [Uri]              $uri
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		if ($null -eq $body)
		{
			# invoke web request
			return Invoke-WebRequest -Authentication Bearer -Method $method -Token $accessToken -Uri $uri -Verbose:$isVerbose;
		}

		$requestBody = $body | ConvertTo-Json -Compress -Depth 100;

		# invoke web request
		return Invoke-WebRequest -Authentication Bearer -Body $requestBody -ContentType 'application/json' -Method $method -Token $accessToken -Uri $uri -Verbose:$isVerbose;
	}
}

function InvokeWebRequestAndGetComplete
{
	[CmdletBinding()]
	[OutputType([WebResponseObject])]
	param
	(
		[Parameter(Mandatory = $true)]  [SecureString]     $accessToken,
		[Parameter(Mandatory = $false)] [Object]           $body = $null,
		[Parameter(Mandatory = $true)]  [WebRequestMethod] $method,
		[Parameter(Mandatory = $true)]  [Uri]              $uri
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# invoke web request to get operation status uri
		$response = InvokeWebRequest -accessToken $accessToken -body $body -method $method -uri $uri -Verbose:$isVerbose;

		if (!$response.Headers.ContainsKey('Location'))
		{
			return $response;
		}

		# get status uri
		$statusUri = $response.Headers['Location'][0];

		while ($true)
		{
			# invoke web request to get status update
			$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $statusUri -Verbose:$isVerbose;

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
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

function Environment.Create
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = '2024-05-01',
		[Parameter(Mandatory = $true)]  [ValidateNotNull()]        [Object]       $settings
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create web request uri
		$uri = "$($EnvironmentApiUri)/environments?api-version=$($apiVersion)&retainOnProvisionFailure=false";

		# invoke web request to create environment and get to completion
		$response = InvokeWebRequestAndGetComplete -accessToken $accessToken -body $settings -method Post -uri $uri -verbose $isVerbose;

		# get environment name
		$name = ($response.Content | ConvertFrom-Json -AsHashtable).links.environment.path.Split('/')[4];

		# retrieve environment info
		$result = Environment.Retrieve -accessToken $accessToken -apiVersion $apiVersion -name $name -verbose $isVerbose;

		return $result;
	}
}

function Environment.Delete
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = '2021-04-01',
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $name
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
		$validateResponse = InvokeWebRequest -accessToken $accessToken -method Post -uri $validateUri -verbose $isVerbose;

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
		$null = InvokeWebRequestAndGetComplete -accessToken $accessToken -method Delete -uri $deleteUri -verbose $isVerbose;

		return $true;
	}
}

function Environment.Retrieve
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = '2024-05-01',
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $name
	)
	process
	{
		# create web request uri
		$uri = "$($EnvironmentApiUri)/scopes/admin/environments/$($name)?api-version=$($apiVersion)&$($EnvironmentSelect)";

		# invoke web request to get environment info
		$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $uri -verbose $isVerbose;

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

function Environment.RetrieveAll
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = '2024-05-01'
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create web request uri
		$uri = "$($EnvironmentApiUri)/scopes/admin/environments?api-version=$($apiVersion)&$($EnvironmentSelect)";

		# invoke web request to get all accessible environments | OData $filter does not work :(
		$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $uri -verbose $isVerbose;

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

function Environment.Update
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = '2024-05-01',
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $name,
		[Parameter(Mandatory = $true)]  [ValidateNotNull()]        [Object]       $settings
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create web request uri
		-uri "$($EnvironmentApiUri)/scopes/admin/environments/$($name)?api-version=$($apiVersion)" `
		
		# invoke web request to update the environment and get to completion
		$null = InvokeWebRequestAndGetComplete -accessToken $accessToken -body $settings -uri $uri -method Patch -verbose $isVerbose;

		# retrieve environment info
		$result = Environment.Retrieve -accessToken $accessToken -apiVersion $apiVersion -name $name -verbose $isVerbose;

		return $result;
	}
}

<# ###################################### #>
<# Functions to manage Managed Identities #>
<# ###################################### #>

function ManagedIdentity.CreateIfNotExist
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $applicationId,
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $environmentUrl,
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $id,
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $tenantId
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# check if identity exist
		$exist = ManagedIdentity.Exist -accessToken $accessToken -apiVersion $apiVersion -environmentUrl $environmentUrl -id $id -isVerbose $isVerbose;

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
		$response = InvokeWebRequestAndGetComplete -accessToken $accessToken -body $body -method Post -uri $uri -verbose $isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

		# create result from response
		$result = [ordered]@{
			id = $responseContent.managedidentityid
		};

		return $result;
	}
}

function ManagedIdentity.DeleteIfExist
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $id,
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $environmentUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# check if identity exist
		$exist = ManagedIdentity.Exist -accessToken $accessToken -apiVersion $apiVersion -environmentUrl $environmentUrl -id $id -verbose $isVerbose;

		if (!$exist)
		{
			return $false;
		}

		# create web request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/managedidentities($($id))";

		# invoke web request
		$null = InvokeWebRequest -accessToken $accessToken -method Delete -uri $uri -verbose $isVerbose;

		return $true;
	}
}

<# ################################ #>
<# Functions to manage System Users #>
<# ################################ #>

function SystemUser.CreateIfNotExist
{
	<#
	.SYNOPSIS
		Create a System User within the Power Platform Environment.
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
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'.
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
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $applicationId,
		[Parameter(Mandatory = $false)]                            [String]       $businessUnitId = $null,
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $environmentUrl,
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String[]]     $roleIds
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# check if system user exist
		$systemUser = SystemUser.Retrieve -accessToken $accessToken -apiVersion $apiVersion -filter "applicationid eq $($applicationId)" -environmentUrl $environmentUrl -verbose $isVerbose;

		if ($null -ne $systemUser)
		{
			return [ordered]@{
				id = $systemUser.systemuserid
			};
		}

		# check if business unit is specified
		if ([String]::IsNullOrEmpty($businessUnitId))
		{
			# set business unit id
			$businessUnitId = BusinessUnit.GetRoot -accessToken $accessToken -apiVersion $apiVersion -environmentUrl $environmentUrl -verbose $isVerbose;
		}

		# create request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/systemusers";

		# create request body
		$requestBody = @{
			accessmode                  = 4
			'businessunitid@odata.bind' = "/businessunits($businessUnitId)"
			applicationid               = $applicationId
			isdisabled                  = $false
		};

		# make request
		$response = InvokeWebRequestAndGetComplete -accessToken $accessToken -body $requestBody -method Post -uri $uri -verbose $isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;
		
		# create result from response
		$result = [ordered]@{
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
			$null = InvokeWebRequest -accessToken $accessToken -body $requestBody -method Post -uri $uri -verbose $isVerbose;

			$result.roleIds.Add($roleId);
		}

		# return result
		return $result;
	}
}

function SystemUser.DeleteIfExist
{
	<#
	.SYNOPSIS
		Delete a System User from the Power Platform environment.
	.DESCRIPTION
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/systemuser
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER apiVersion
		Version of the Power Platform API to use.
	.PARAMETER environmentUrl
		Url of the Power Platform Environment.
		Format 'https://[DomainName].[DomainSuffix].dynamics.com/'.
	.PARAMETER id
		Id of the System User within the Power Platform Environment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [SecureString] $accessToken,
		[Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [String]       $apiVersion = 'v9.2',
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $id,
		[Parameter(Mandatory = $true)]  [ValidateNotNullOrEmpty()] [String]       $environmentUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# check if system user exist
		$systemUser = SystemUser.Retrieve -accessToken $accessToken -apiVersion $apiVersion -filter "systemuserid eq $($id)" -environmentUrl $environmentUrl -verbose $isVerbose;

		if ($null -eq $systemUser)
		{
			return $false;
		}

		# create request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/systemusers($($id))";

		# execute disable request
		$null = InvokeWebRequestAndGetComplete -accessToken $accessToken -body @{ isdisabled = $true } -method Patch -uri $uri -verbose $isVerbose;

		# execute delete request
		# this request changes state to deleted
		$null = InvokeWebRequest -accessToken $accessToken -method Delete -uri $uri -verbose $isVerbose;

		# execute delete request
		# this is actual delete
		$null = InvokeWebRequest -accessToken $accessToken -method Delete -uri $uri -verbose $isVerbose;

		return $true;
	}
}

<# ######################### #>
<# Internal helper functions #>
<# ######################### #>

function BusinessUnit.GetRoot
{
	[OutputType([String])]
	param
	(
		[SecureString] $accessToken,
		[String]       $apiVersion,
		[String]       $environmentUrl,
		[Boolean]      $verbose
	)
	process
	{
		# create request uri to get root business unit
		$uri = "$($environmentUrl)api/data/$($apiVersion)/businessunits?%24select=businessunitid&%24filter=_parentbusinessunitid_value%20eq%20null";

		# execute request
		$response = InvokeWebRequest -accessToken $accessToken -method Get -Uri $uri -verbose $verbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

		# get business unit id
		$result = $responseContent.value[0].businessunitid;

		return $result;
	}
}

function ManagedIdentity.Exist
{
	[OutputType([String])]
	param
	(
		[SecureString] $accessToken,
		[String]       $apiVersion,
		[String]       $environmentUrl,
		[String]       $id,
		[Boolean]      $verbose
	)
	process
	{
		# create web request uri
		$uri = "$($environmentUrl)api/data/$($apiVersion)/managedidentities?`$select=managedidentityid&`$filter=managedidentityid eq '$($id)'";

		# invoke web request to check if managed identity exist
		$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $uri -verbose $verbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

		if ($responseContent.value.Count -eq 1)
		{
			return $true;
		}

		return $false;
	}
}

function SystemUser.Retrieve
{
	[OutputType([String])]
	param
	(
		[SecureString] $accessToken,
		[String]       $apiVersion,
		[String]       $environmentUrl,
		[String]       $filter,
		[Boolean]      $verbose
	)
	process
	{
		$uri = "$($environmentUrl)api/data/$($apiVersion)/systemusers?`$select=applicationid,systemuserid&`$filter=$($filter)";

		# invoke web request to check if managed identity exist
		$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $uri -verbose $verbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json -AsHashtable;

		$result = $null;

		if ($responseContent.value.Count -eq 1)
		{
			$result = $responseContent.value[0]
		}

		return $result;
	}
}

function InvokeWebRequest
{
	[OutputType([WebResponseObject])]
	param
	(
		[SecureString]     $accessToken,
		[Object]           $body = $null,
		[WebRequestMethod] $method,
		[Uri]              $uri,
		[Boolean]          $verbose
	)
	process
	{
		if ($null -eq $body)
		{
			# invoke web request
			return Invoke-WebRequest -Authentication Bearer -Method $method -Token $accessToken -Uri $uri -Verbose:$verbose;
		}

		$requestBody = $body | ConvertTo-Json -Compress -Depth 100;

		# invoke web request
		return Invoke-WebRequest -Authentication Bearer -Body $requestBody -ContentType 'application/json' -Method $method -Token $accessToken -Uri $uri -Verbose:$verbose;
	}
}

function InvokeWebRequestAndGetComplete
{
	[OutputType([WebResponseObject])]
	param
	(
		[SecureString]     $accessToken,
		[Object]           $body = $null,
		[WebRequestMethod] $method,
		[Uri]              $uri,
		[Boolean]          $verbose
	)
	process
	{
		# invoke web request to get operation status uri
		$response = InvokeWebRequest -accessToken $accessToken -body $body -method $method -uri $uri -verbose $verbose;

		if (!$response.Headers.ContainsKey('Location'))
		{
			return $response;
		}

		# get status uri
		$statusUri = $response.Headers['Location'][0];

		while ($true)
		{
			# invoke web request to get status update
			$response = InvokeWebRequest -accessToken $accessToken -method Get -uri $statusUri -verbose $verbose;

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
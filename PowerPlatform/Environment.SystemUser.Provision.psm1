function PowerPlatform.Environment.SystemUser.Provision
{
	<#
	.SYNOPSIS
		Provision a System User within the Power Platform Environment.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/systemuser
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com'.
	.PARAMETER applicationId
		Application (Client) Id of the Service Principal within the Entra tenant.
	.PARAMETER businessUnitId
		Unique identifier of the Business Unit with which the User is associated.
	.PARAMETER instanceUrl
		Url of the Power Platform Environment.
	.OUTPUTS
		System.Object
			id : System User Id
			roleIds : collection of Ids of assigned Roles
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[Parameter(Mandatory = $true)]	[String]		$applicationId,
		[Parameter(Mandatory = $false)]	[String]		$businessUnitId = $null,
		[Parameter(Mandatory = $true)]	[String]		$instanceUrl,
		[Parameter(Mandatory = $true)]	[String[]]		$roleIds
	)
	process
	{
		$apiVersion = 'v9.2';

		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		if ([String]::IsNullOrEmpty($businessUnitId))
		{
			# create request uri to get root business unit
			$requestUri = "$($instanceUrl)api/data/$($apiVersion)/businessunits?%24select=businessunitid%2Cname%2C_parentbusinessunitid_value&%24filter=_parentbusinessunitid_value%20eq%20null";

			# execute request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
				-Method Get `
				-Token $accessToken `
				-Uri $requestUri `
				-Verbose:$isVerbose;

			# convert response content
			$responseContent = $response.Content | ConvertFrom-Json;

			# set business unit id
			$businessUnitId = $responseContent.Value[0].businessunitid;
		}

		# create request uri
		$requestUri = "$($instanceUrl)api/data/$($apiVersion)/systemusers";

		# create request body
		$requestBody = [PSCustomObject]@{
			accessmode					= 4
			'businessunitid@odata.bind'	= "/businessunits($businessUnitId)"
			applicationid				= $applicationId
			isdisabled					= $false
		};

		# make request
		$response = PowerPlatform.Helpers.InvokeCreate -accessToken $accessToken -body $requestBody -uri $requestUri -waitStatusCode 204 -Verbose:$isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json;
		
		# create result from response
		$result = @{
			id = $responseContent.systemuserid
			roleIds = [System.Collections.Generic.List[String]]::new()
		};

		foreach ($roleId in $roleIds)
		{
			# create request uri
			$requestUri = "$($instanceUrl)api/data/$($apiVersion)/systemusers($($result.id))%2Fsystemuserroles_association%2F%24ref";

			# create request body
			$requestBody = [PSCustomObject]@{
				'@odata.id' = "$($instanceUrl)api/data/$($apiVersion)/roles($roleId)"
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

Export-ModuleMember -Function PowerPlatform.Environment.SystemUser.Provision;

function PowerPlatform.Helpers.InvokeCreate
{
	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[Parameter(Mandatory = $true)]	[Object]		$body,
		[Parameter(Mandatory = $true)]	[String]		$uri,
		[Parameter(Mandatory = $true)]	[Int32]			$waitStatusCode
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		$requestBody = $body | ConvertTo-Json -Compress -Depth 100;

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Body $requestBody `
			-ContentType 'application/json' `
			-Method Post `
			-Token $accessToken `
			-Uri $uri `
			-Verbose:$isVerbose;

		if ($response.StatusCode -eq $waitStatusCode)
		{
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

				if ($response.Headers.ContainsKey('Retry-After'))
				{
					# get amount of seconds to sleep
					$retryAfter = [Int32] $response.Headers['Retry-After'][0];

					# fall sleep
					Start-Sleep -s $retryAfter;
				}
				else
				{
					break;
				}
			}
		}

		# return response
		return $response;
	}
}

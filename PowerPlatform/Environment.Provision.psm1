function PowerPlatform.Environment.Provision
{
	<#
	.SYNOPSIS
		Provision an environment within the Power Platform tenant.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER settings
		Object that contains all settings required to create an environment.
	.OUTPUTS
		System.Object
		On object with following fields:
			- azureRegion		[System.String]
			- domainName		[System.String]
			- instanceUrl		[System.String]
			- name				[System.String]
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[parameter(Mandatory = $false)]	[string]		$apiVersion = '2024-05-01',
		[Parameter(Mandatory = $true)]	[Object]		$settings
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create request uri
		$requestUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=$($apiVersion)&retainOnProvisionFailure=false";

		# make request and wait till complete
		$response = PowerPlatform.Helpers.InvokeCreate `
			-accessToken $accessToken `
			-body $settings `
			-uri $requestUri `
			-waitStatusCode 202 `
			-Verbose:$isVerbose;

		# get environment name
		$environmentName = ($response.Content | ConvertFrom-Json).links.environment.path.Split('/')[4];

		# create request uri
		$requestUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($environmentName)?api-version=$($apiVersion)";

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-ContentType 'application/json' `
			-Method Get `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:$isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json;

		# create projection and return as result
		return @{
			azureRegion = $responseContent.properties.azureRegion
			domainName  = $responseContent.properties.linkedEnvironmentMetadata.domainName
			instanceUrl = $responseContent.properties.linkedEnvironmentMetadata.instanceUrl
			name        = $responseContent.name
		};
	}
}

Export-ModuleMember -Function PowerPlatform.Environment.Provision;

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

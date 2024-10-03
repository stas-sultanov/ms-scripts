<<<<<<< HEAD
function PowerPlatform.Environment.Provision
=======
function PowerPlatform.Environment.Provsion
>>>>>>> 857178606eef4bd733eb052235ba02054589f848
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
		[Parameter(Mandatory = $true)]	[Object]		$settings
	)
	process
	{
		$isVerbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true;

		# create request url
		$requestUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2021-04-01&retainOnProvisionFailure=false';

		Write-Verbose $requestUri;

		$requestBody = $settings | ConvertTo-Json -Compress -Depth 100;

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Body $requestBody `
			-ContentType 'application/json' `
			-Method Post `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:($isVerbose);

		$statusUri = $response.Headers['Location'][0];

		#Wait until the environment has been created or the service timeout
		while ($response.Headers.ContainsKey('Retry-After'))
		{
			# get amount of seconds to sleep
			$retryAfter = [Int32] $response.Headers['Retry-After'][0];

			# fall sleep
			Start-Sleep -s $retryAfter;

			# make request
			$response = Invoke-WebRequest `
				-Authentication Bearer `
				-Method Get `
				-Token $accessToken `
				-Uri $statusUri `
				-Verbose:($isVerbose);
		} 

		# get environment name
		$environmentName = ($response.Content | ConvertFrom-Json).links.environment.path.Split('/')[4];

		# create request uri
		$requestUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($environmentName)?api-version=2021-04-01";

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-ContentType 'application/json' `
			-Method Get `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:($isVerbose);

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

<<<<<<< HEAD
Export-ModuleMember -Function PowerPlatform.Environment.Provision;
=======
Export-ModuleMember -Function PowerPlatform.Environment.Provsion;
>>>>>>> 857178606eef4bd733eb052235ba02054589f848

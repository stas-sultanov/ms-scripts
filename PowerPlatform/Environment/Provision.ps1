<#
	author:		Stas Sultanov
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Creates an environment within the Power Platform tenant.
.DESCRIPTION
	Can be executed by Identity which has Power Platform Administrator role within Entra.
.NOTES
	Copyright © 2024 Stas Sultanov.
.PARAMETER accessToken
	Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
.PARAMETER settings
	Object that contains all settings required to create an environment.
.OUTPUTS
	System.String
	Environment Id.
#>

[CmdletBinding(DefaultParameterSetName = "User")]
param
(
	[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
	[Parameter(Mandatory = $true)]	[Object]		$settings
)
process {
	$isVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true;

	# create request url
	$requestUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments?api-version=2021-04-01&retainOnProvisionFailure=false";

	Write-Verbose $requestUri;

	$requestBody = $settings | ConvertTo-Json -Compress -Depth 100;

	# execute request
	$response = Invoke-WebRequest `
		-Authentication Bearer `
		-Body $requestBody `
		-ContentType "application/json" `
		-Method Post `
		-Token $accessToken `
		-Uri $requestUri `
		-Verbose:($isVerbose);

	$statusUri = $response.Headers['Location'][0];

	#Wait until the environment has been created or the service timeout
	do {
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
	} while ($response.StatusCode -ne 200);

	# get environment id
	$result = ($response.Content | ConvertFrom-Json).links.environment.path.Split('/')[4];

	return $result;
}
function PowerPlatform.Environment.Remove
{
	<#
	.SYNOPSIS
		Remove an environment from the Power Platform tenant.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://service.powerapps.com/'.
	.PARAMETER environmentName
		Name of the Power Platform environment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[Parameter(Mandatory = $true)]	[String]		$environmentName
	)
	process
	{
		$isVerbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true;

		$environmentsRequestUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments';

		# create request uri to validate delete
		$requestUri = "$environmentsRequestUri/$environmentName/validateDelete?api-version=2021-04-01";

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Post `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:($isVerbose);

		# get content
		$responseContent = $response.Content | ConvertFrom-Json;

		if (-not $responseContent.canInitiateDelete)
		{
			return 'can not delete';
		}

		# create request uri to delete
		$requestUri = "$environmentsRequestUri/$environmentName?api-version=2021-04-01";

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:($isVerbose);

		$statusUri = $response.Headers['Location'][0];

		#Wait until the environment has been deleted
		do
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
		} while (($response.StatusCode -ne 404) -and $response.Headers.ContainsKey('Retry-After'));
	}
}

Export-ModuleMember -Function PowerPlatform.Environment.Remove;

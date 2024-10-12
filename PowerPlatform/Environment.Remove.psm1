function PowerPlatform.Helpers.InvokeDeleteAndWait
{
	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]		$accessToken,
		[Parameter(Mandatory = $true)]	[String]			$uri
	)
	process
	{
		$isVerbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true;

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:($isVerbose);

		if ($response.StatusCode -eq 202)
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
					-Verbose:($isVerbose);

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
		[parameter(Mandatory = $false)]	[string]		$apiVersion = '2021-04-01',
		[Parameter(Mandatory = $true)]	[String]		$environmentName
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		$baseUri = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments';

		# create request uri to validate delete
		$requestUri = "$($baseUri)/$($environmentName)/validateDelete?api-version=$($apiVersion)";

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
		$requestUri = "$($baseUri)/$($environmentName)?api-version=$($apiVersion)";

		# make request and wait till complete
		$null = PowerPlatform.Helpers.InvokeDeleteAndWait -accessToken $accessToken -uri $requestUri -Verbose:($isVerbose);
	}
}

Export-ModuleMember -Function PowerPlatform.Environment.Remove;

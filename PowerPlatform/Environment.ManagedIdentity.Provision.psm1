function PowerPlatform.Environment.ManagedIdentity.Provision
{
	<#
	.SYNOPSIS
		Provision a Managed Identity within the Power Platform Environment.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator Role within Entra.
		More information here: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/managedidentity
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com'.
	.PARAMETER applicationId
		Application (Client) Id of the Service Principal within the Entra tenant.
	.PARAMETER id
		Id of the Managed Identity within Power Platform Environment.
	.PARAMETER instanceUrl
		Url of the Power Platform environment.
	.PARAMETER tenantId
		Id of the Entra tenant.
	.OUTPUTS
		System.Object
			id : Environment Id
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[Parameter(Mandatory = $true)]	[String]		$applicationId,
		[Parameter(Mandatory = $false)]	[String]		$id = (New-Guid).Guid,
		[Parameter(Mandatory = $true)]	[String]		$instanceUrl,
		[Parameter(Mandatory = $true)]	[String]		$tenantId
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create request uri
		$requestUri = "$($instanceUrl)api/data/v9.2/managedidentities";

		# create request body
		$requestBody = @{
			applicationid     = $applicationId
			credentialsource  = 2
			managedidentityid = $id
			subjectscope      = 1
			tenantid          = $tenantId
		};

		# make request
		$response = PowerPlatform.Helpers.InvokeCreate -accessToken $accessToken -body $requestBody -uri $requestUri -waitStatusCode 204 -Verbose:$isVerbose;

		# convert response content
		$responseContent = $response.Content | ConvertFrom-Json;

		# create result from response
		$result = @{
			id = $responseContent.managedidentityid
		};

		# return result
		return $result;
	}
}

Export-ModuleMember -Function PowerPlatform.Environment.ManagedIdentity.Provision;

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

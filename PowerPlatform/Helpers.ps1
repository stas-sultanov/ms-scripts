function PowerPlatform.Helpers.RequestCreateAndWait
{
	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]		$accessToken,
		[Parameter(Mandatory = $true)]	[String]			$uri,
		[Parameter(Mandatory = $true)]	[PSCustomObject]	$body
	)
	process
	{
		$isVerbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true;

		$requestBody = $body | ConvertTo-Json -Compress -Depth 100;

		# execute request
		$response = Invoke-WebRequest `
			-Authentication Bearer `
			-Body $requestBody `
			-ContentType 'application/json' `
			-Method Post `
			-Token $accessToken `
			-Uri $uri `
			-Verbose:($isVerbose);

		if ($response.StatusCode -eq 204)
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

function PowerPlatform.Environment.ManagedIdentity.Remove
{
	<#
	.SYNOPSIS
		Remove a Managed Identity from the Power Platform environment.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
		Use this api: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/managedidentity
	.PARAMETER accessToken
		Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com'.
	.PARAMETER id
		Id of the Managed Identity within the Power Platform Enviornment.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[Parameter(Mandatory = $true)]	[String]		$id,
		[Parameter(Mandatory = $true)]	[String]		$instanceUrl
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# create request uri
		$requestUri = "$($instanceUrl)api/data/v9.2/managedidentities($($id))";

		# execute request
		$null = Invoke-WebRequest `
			-Authentication Bearer `
			-Method Delete `
			-Token $accessToken `
			-Uri $requestUri `
			-Verbose:$isVerbose;
	}
}

Export-ModuleMember -Function PowerPlatform.Environment.ManagedIdentity.Remove;

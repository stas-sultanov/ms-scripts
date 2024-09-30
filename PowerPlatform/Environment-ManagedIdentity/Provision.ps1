<#
	author:		Stas Sultanov
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Provision a Managed Identity within the Power Platform environment.
.DESCRIPTION
	Can be executed by Identity which has Power Platform Administrator role within Entra.
	Use this api: https://learn.microsoft.com/power-apps/developer/data-platform/webapi/reference/managedidentity
.NOTES
	Copyright © 2024 Stas Sultanov.
.PARAMETER accessToken
	Bearer token to access. The token AUD must include 'https://[DomainName].[DomainSuffix].dynamics.com'.
.PARAMETER clientId
	Client Id of the Managed Identity within the Entra tenant.
.PARAMETER id
	Id of the Managed Identity within Power Platform.
.PARAMETER instanceUrl
	Url of the Power Platform environment.
.PARAMETER tenantId
	Id of the Entra tenant.
.OUTPUTS
	System.String
	Environment Id.
#>

[CmdletBinding(DefaultParameterSetName = "User")]
param
(
	[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
	[Parameter(Mandatory = $true)]	[String]		$clientId,
	[Parameter(Mandatory = $false)]	[String]		$id = (New-Guid).Guid,
	[Parameter(Mandatory = $true)]	[String]		$instanceUrl,
	[Parameter(Mandatory = $true)]	[String]		$tenantId
)
process {
	$isVerbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -eq $true;

	# create request uri
	$requestUri = "$($instanceUrl)api/data/v9.2/managedidentities";

	# create request body
	$requestBody = [PSCustomObject]@{
		applicationid     = $clientId
		credentialsource  = 2
		managedidentityid = $id
		subjectscope      = 1
		tenantid          = $tenantId
	} | ConvertTo-Json -Compress;

	# execute request
	$null = Invoke-WebRequest `
		-Authentication Bearer `
		-Body $requestBody `
		-ContentType "application/json" `
		-Method Post `
		-Token $accessToken `
		-Uri $requestUri `
		-Verbose:($isVerbose);

	# return Managed Identity Id as result
	return $id;
}

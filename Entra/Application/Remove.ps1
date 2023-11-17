<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Remove an Application Registration within the Entra ID tenant.
.DESCRIPTION
	Uses Microsoft.Graph Powershell module.
.NOTES
	Copyright © 2023 Stas Sultanov.
.PARAMETER accessToken
	Bearer token to access MS Graph.
.PARAMETER objectId
	Directory ObjectId of the Application Registration.
#>

param
(
	[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
	[parameter(Mandatory = $true)]	[String]		$objectId
)

<# implementation #>

# connect to Graph
Connect-MgGraph -AccessToken $accessToken -NoWelcome;

# check if object exists
$object = Get-MgApplication -Filter "Id eq '$objectId'";

if ($null -eq $object)
{
	Write-Host "Application Registration does not exist";

	return;
}

Write-Host "Application Registration Delete";

# remove object
Remove-MgApplication -ApplicationId $objectId;
<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Provision a Group within the Entra ID tenant.
.DESCRIPTION
	Script assumes that names of the groups are unique within the Entra ID tenant.
	Uses Microsoft.Graph Powershell module.
.NOTES
	Copyright © 2023 Stas Sultanov
.PARAMETER accessToken
	A bearer token for Microsoft Graph service.
.PARAMETER groupName
	Name of the Application.
.PARAMETER manifestFileName
	Name of the Manifest file, including path.
.OUTPUTS
	System.Guid
	Group Object Id.
#>

using namespace Microsoft.Graph.PowerShell.Models;

param
(
	[parameter(Mandatory = $true)] [String] $accessToken,
	[parameter(Mandatory = $true)] [String] $groupName,
	[parameter(Mandatory = $true)] [String] $manifestFileName
)

<# implementation #>

# secure access token
$accessTokenSecured = $accessToken | ConvertTo-SecureString -AsPlainText -Force;

# connect to Microsoft Graph
Connect-MgGraph -AccessToken $accessTokenSecured -NoWelcome;

<# read manifest file #>

$manifest = Get-Content $manifestFileName | out-string | ConvertFrom-Json -AsHashtable;

<# get or create group #>

# get all groups with DisplayName specified
$group = Get-MgGroup -Filter "DisplayName eq '$groupName'";

# check if there is more then one group
if ($group -is [array])
{
	throw "Directory query returned more than one Group with DisplayName eq [$groupName].";
}

# check if group not exist
if ($null -eq $group)
{
	Write-Host "Group Create";

	$param = @{
		Description				= $manifest.Description
		DisplayName				= $groupName
		GroupTypes				= @()
		IsAssignableToRole		= $false
		MailEnabled				= $false
		MailNickname			= $groupName
		"Members@odata.bind"	= $manifest.Members
		"Owners@odata.bind"		= $manifest.Owners
		SecurityEnabled			= $true
	}

	$group = New-MgGroup -BodyParameter $param;
}
else
{
	Write-Host "Group Update";

	$param = @{
		Description				= $manifest.Description
#		"Members@odata.bind"	= $manifest.Members
#		"Owners@odata.bind"		= $manifest.Owners
	}

	$group = Update-MgGroup -GroupId $group.Id -BodyParameter $param
}

<# return result #>

return @{
	Id = $group.Id
};
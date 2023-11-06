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
	[parameter(Mandatory = $true)] [String] $groupName,
	[parameter(Mandatory = $true)] [String] $manifestFileName
)

<# implementation #>

# get access token
$accessToken = Get-AzAccessToken -ResourceTypeName MSGraph;

# get objectId of the service principal that executes this script
$currentPrincipalObjectId = (Get-AzADServicePrincipal -ApplicationId $accessToken.UserId).Id;

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
		SecurityEnabled			= $true
	}

	$group = New-MgGroup -BodyParameter $param;
}
else
{
	Write-Host "Group Update";

	if ($group.Description -ne $manifest.Description)
	{
		$group = Update-MgGroup -GroupId $group.Id -Description $manifest.Description
	}
}

<# provision Owners #>

# get owners from manifest
$ownerIdList = @();

if ($null -ne $manifest.Owners)
{
	$ownerIdList = $manifest.Owners | ForEach-Object { [MicrosoftGraphDirectoryObject]::DeserializeFromDictionary($_) } | Select-Object -ExpandProperty Id;
}

# get existing owners
$existingOwnerIdList = Get-MgGroupOwner -GroupId $group.Id | Select-Object -ExpandProperty Id;

# get owners to add, by excluding existing owners from specified in manifest
$toAddOwnerIdList = $ownerIdList | Where-Object { $_ -notin $existingOwnerIdList };

foreach ($ownerId in $toAddOwnerIdList)
{
	Write-Host "Group Add Owner [$ownerId]";

	# add owner
	New-MgGroupOwnerByRef -GroupId $group.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$ownerId"
}

# get owners to remove, excluding current identity
$toRemoveOwnerIdList = $existingOwnerIdList | Where-Object { ($_ -ne $currentPrincipalObjectId) -and ($_ -notin $ownerIdList) };

foreach ($ownerId in $toRemoveOwnerIdList)
{
	Write-Host "Group Remove Owner [$ownerId]";

	# remove owner
	Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $ownerId;
}

<# return result #>

return @{
	Id = $group.Id
};
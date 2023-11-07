<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Provision a Group within the Entra ID tenant.
.DESCRIPTION
	Script assumes that names of groups are unique within the Entra ID tenant.
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

using namespace System.Collections.Generic;
using namespace Microsoft.Graph.PowerShell.Models;

param
(
	[parameter(Mandatory = $true)]	[String]	$accessToken,
	[parameter(Mandatory = $false)]	[String[]]	$extraMembers = @(),
	[parameter(Mandatory = $false)]	[String[]]	$extraOwners = @(),
	[parameter(Mandatory = $true)]	[String]	$groupName,
	[parameter(Mandatory = $true)]	[String]	$manifestFileName
)

<# implementation #>

# secure access token
$accessTokenSecured = $accessToken | ConvertTo-SecureString -AsPlainText -Force;

# connect to Graph
Connect-MgGraph -AccessToken $accessTokenSecured -NoWelcome;

<# read manifest file #>

$manifest = Get-Content $manifestFileName | out-string | ConvertFrom-Json -AsHashtable;

<# get or create group #>

# get all groups with DisplayName eq to specified
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
		Write-Host "Group Update Description";

		$group = Update-MgGroup -GroupId $group.Id -Description $manifest.Description;
	}
}

<# provision Members #>

# get members from manifest
$memberIdList = [List[String]] ($manifest.Members | ForEach-Object { [MicrosoftGraphDirectoryObject]::DeserializeFromDictionary($_) } | Select-Object -ExpandProperty Id);

# add extra members specfied
$memberIdList.AddRange($extraMembers);

# get existing members
$existingMemberIdList = Get-MgGroupMember -GroupId $group.Id | Select-Object -ExpandProperty Id;

# get members to add, by excluding existing members from specified in manifest
$toAddMemberIdList = $memberIdList | Where-Object { $_ -notin $existingMemberIdList };

foreach ($memberId in $toAddMemberIdList)
{
	Write-Host "Group Add Member [$memberId]";

	# add
	New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $memberId;
}

# get members to remove
$toRemoveMemberIdList = $existingMemberIdList | Where-Object { $_ -notin $memberIdList };

foreach ($memberId in $toRemoveMemberIdList)
{
	Write-Host "Group Remove Member [$memberId]";

	# remove
	Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $memberId;
}

<# provision Owners #>

# get owners from manifest
$ownerIdList = [List[String]] ($manifest.Owners | ForEach-Object { [MicrosoftGraphDirectoryObject]::DeserializeFromDictionary($_) } | Select-Object -ExpandProperty Id);

# add extra owners specified
$ownerIdList.AddRange($extraOwners);

# get existing owners
$existingOwnerIdList = Get-MgGroupOwner -GroupId $group.Id | Select-Object -ExpandProperty Id;

# get owners to add, by excluding existing owners from specified in manifest
$toAddOwnerIdList = $ownerIdList | Where-Object { $_ -notin $existingOwnerIdList };

foreach ($ownerId in $toAddOwnerIdList)
{
	Write-Host "Group Add Owner [$ownerId]";

	# add owner
	New-MgGroupOwner -GroupId $group.Id -DirectoryObjectId $ownerId;
}

# get owners to remove, excluding current identity
$toRemoveOwnerIdList = $existingOwnerIdList | Where-Object { $_ -notin $ownerIdList };

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
using namespace System.Collections.Generic;
using namespace Microsoft.Graph.Beta.PowerShell.Models;

function Entra.Group.Provision
{
	<#
	.SYNOPSIS
		Provision a Group within the Entra ID tenant.
	.DESCRIPTION
		Script assumes that names of groups are unique within the Entra ID tenant.
		Uses Microsoft.Graph.Beta Powershell module.
	.PARAMETER accessToken
		Bearer token to access MS Graph.
	.PARAMETER extraMembers
		List of extra Object Ids of the Identities within the Entra ID tenant to add as Member to the Group.
	.PARAMETER extraOwners
		List of extra Object Ids of the Identities within the Entra ID tenant to add as Owner to the Group.
	.PARAMETER manifestFileName
		Name of the Manifest file, including path.
	.PARAMETER name
		Name of the Group.
	.OUTPUTS
		System.Object
		On object with following fields:
			[System.Guid]	id
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[parameter(Mandatory = $false)] [String[]]     $extraMembers = @(),
		[parameter(Mandatory = $false)] [String[]]     $extraOwners = @(),
		[parameter(Mandatory = $true)]  [String]       $manifestFileName,
		[parameter(Mandatory = $true)]  [String]       $name
	)
	process
	{
		<# implementation #>

		# connect to Graph
		Connect-MgGraph -AccessToken $accessToken -NoWelcome;

		<# read manifest file #>

		$manifest = Get-Content $manifestFileName | Out-String | ConvertFrom-Json -AsHashtable;

		<# get or create group #>

		# get all groups with DisplayName eq to specified
		$group = Get-MgBetaGroup -Filter "DisplayName eq '$name'";

		# check if there is more then one group
		if ($group -is [array])
		{
			throw "Directory query returned more than one Group with DisplayName eq [$name].";
		}

		# check if group not exist
		if ($null -eq $group)
		{
			Write-Host 'Group Create';

			$param = @{
				Description        = $manifest.Description
				DisplayName        = $name
				GroupTypes         = @()
				IsAssignableToRole = $false
				MailEnabled        = $false
				MailNickname       = $name
				SecurityEnabled    = $true
			}

			$group = New-MgBetaGroup -BodyParameter $param;
		}
		else
		{
			Write-Host 'Group Update';

			if ($group.Description -ne $manifest.Description)
			{
				Write-Host 'Group Update Description';

				$group = Update-MgBetaGroup -GroupId $group.Id -Description $manifest.Description;
			}
		}

		<# provision Members #>

		# get members from manifest
		$memberIdList = [List[String]] ($manifest.Members | ForEach-Object { [MicrosoftGraphDirectoryObject]::DeserializeFromDictionary($_) } | Select-Object -ExpandProperty Id);

		# add extra members specified
		$memberIdList.AddRange($extraMembers);

		# get existing members
		$existingMemberIdList = Get-MgBetaGroupMember -GroupId $group.Id | Select-Object -ExpandProperty Id;

		# get members to add, by excluding existing members from specified in manifest
		$toAddMemberIdList = $memberIdList | Where-Object { $_ -notin $existingMemberIdList };

		foreach ($memberId in $toAddMemberIdList)
		{
			Write-Host "Group Add Member [$memberId]";

			# add
			New-MgBetaGroupMember -GroupId $group.Id -DirectoryObjectId $memberId;
		}

		# get members to remove
		$toRemoveMemberIdList = $existingMemberIdList | Where-Object { $_ -notin $memberIdList };

		foreach ($memberId in $toRemoveMemberIdList)
		{
			Write-Host "Group Remove Member [$memberId]";

			# remove
			Remove-MgBetaGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $memberId;
		}

		<# provision Owners #>

		# get owners from manifest
		$ownerIdList = [List[String]] ($manifest.Owners | ForEach-Object { [MicrosoftGraphDirectoryObject]::DeserializeFromDictionary($_) } | Select-Object -ExpandProperty Id);

		# add extra owners specified
		$ownerIdList.AddRange($extraOwners);

		# get existing owners
		$existingOwnerIdList = Get-MgBetaGroupOwner -GroupId $group.Id | Select-Object -ExpandProperty Id;

		# get owners to add, by excluding existing owners from specified in manifest
		$toAddOwnerIdList = $ownerIdList | Where-Object { $_ -notin $existingOwnerIdList };

		foreach ($ownerId in $toAddOwnerIdList)
		{
			Write-Host "Group Add Owner [$ownerId]";

			# add owner
			New-MgBetaGroupOwner -GroupId $group.Id -DirectoryObjectId $ownerId;
		}

		# get owners to remove, excluding current identity
		$toRemoveOwnerIdList = $existingOwnerIdList | Where-Object { $_ -notin $ownerIdList };

		foreach ($ownerId in $toRemoveOwnerIdList)
		{
			Write-Host "Group Remove Owner [$ownerId]";

			# remove owner
			Remove-MgBetaGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $ownerId;
		}

		<# return result #>

		return @{
			name     = $name
			objectId = $group.Id
		};
	}
}

Export-ModuleMember -Function Entra.Group.Provision;

function Entra.Group.Remove
{
	<#
	.SYNOPSIS
		Remove a Group within the Entra ID tenant.
	.DESCRIPTION
		Uses Microsoft.Graph Powershell module.
	.PARAMETER accessToken
		Bearer token to access MS Graph.
	.PARAMETER groupObjectId
		Object Id of the Group within the Entra tenant.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[parameter(Mandatory = $true)] [SecureString] $accessToken,
		[parameter(Mandatory = $true)] [String]       $groupObjectId
	)

	<# implementation #>

	# connect to Graph
	Connect-MgGraph -AccessToken $accessToken -NoWelcome;

	# check if object exists
	$object = Get-MgGroup -Filter "Id eq '$objectId'";

	if ($null -eq $object)
	{
		Write-Host 'Group does not exist';

		return;
	}

	Write-Host 'Group Delete';

	# remove object
	Remove-MgGroup -GroupId $objectId;
}

Export-ModuleMember -Function Entra.Group.Remove;
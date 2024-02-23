<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Assign Identity to the specified Role within the Entra ID tenant.
.DESCRIPTION
	Uses Microsoft.Graph Powershell module.
	Can be executed by Identity which has RoleManagement.ReadWrite.Directory permission.
.NOTES
	Copyright © 2023 Stas Sultanov.
.PARAMETER accessToken
	Bearer token to access MS Graph.
.PARAMETER identityObjectId
	ObjectId of the Identity within the Entra ID tenant.
.PARAMETER roleName
	Name of the Role within the Entra ID tenant.
#>

param
(
	[parameter(Mandatory = $true)]	[SecureString]  $accessToken,
	[Parameter(Mandatory = $true)]	[String]        $identityObjectId,
	[Parameter(Mandatory = $true)]	[String]        $roleName
)

# connect to Graph
Connect-MgGraph -AccessToken $accessToken -NoWelcome;

# get role template id by name
$roleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { $_.DisplayName -eq $roleName };

$roleTemplateId = $roleTemplate.Id;

# try get role Id by name
$role = Get-MgDirectoryRole -Filter "RoleTemplateId eq '$roleTemplateId'";

# check if role exists
if ($null -eq $role)
{
	# create role from the template
	$role = New-MgDirectoryRole -RoleTemplateId $roleTemplateId;

	Write-Host "Role [$roleName] created from the template [$roleTemplateId].";
}

# get assignments
$assignments = [Array] (Get-MgRoleManagementDirectoryRoleAssignment -Filter "(PrincipalId eq '$identityObjectId') and (RoleDefinitionId eq '$roleTemplateId')");

if ($assignments.Count -ge 0)
{
	Write-Host "Role [$roleName] is already assigned to the Object with Id [$identityObjectId].";

	Write-Host "Current assignments are: [$($assignments | ConvertTo-Json)].";

	return;
}

# add identity to the role
$graphEndpoint = ( Get-MgEnvironment -Name ( Get-MgContext ).Environment ).GraphEndpoint;

New-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -OdataId "$graphEndpoint/v1.0/directoryObjects/$identityObjectId";

# changes are not propagated to all instances of Entra immediately
# this is why we need to read several times to ensure that changes are propagated
$retryCount = 3;

$retryDelayInSeconds = 15;

$retryDelayIncrementInSeconds = 15;

for ($index = 0; $index -lt $retryCount; $index++)
{
	# wait
	Start-Sleep -Seconds $retryDelayInSeconds;

	# check
	$assignments = [Array] (Get-MgRoleManagementDirectoryRoleAssignment -Filter "(PrincipalId eq '$identityObjectId') and (RoleDefinitionId eq '$roleTemplateId')");

	if ($assignments.Count -ge 0)
	{
		return;
	}

	Write-Warning "Role [$roleName] assignment to Object with Id [$identityObjectId] is not yet propagated to all Entra instances.";

	$retryDelayInSeconds += $retryDelayIncrementInSeconds;
}

Write-Host "Role [$roleName] assigned to Object with Id [$identityObjectId].";

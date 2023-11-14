<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Assign Identity to the specified Role within the Entra ID tenant.
.DESCRIPTION
	Can be executed only by identity with one of the following roles:
	- "Global Administrator"
	- "Privileged Roles Administrator"
	Uses Microsoft.Graph Powershell module.
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
	[parameter(Mandatory = $true)]	[String]		$accessToken,
	[Parameter(Mandatory = $true)]	[System.String]	$identityObjectId,
	[Parameter(Mandatory = $true)]	[System.String]	$roleName
)

# secure access token
$accessTokenSecured = $accessToken | ConvertTo-SecureString -AsPlainText -Force;

# connect to Graph
Connect-MgGraph -AccessToken $accessTokenSecured -NoWelcome;

# get role template id by name
$roleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { $_.DisplayName -eq $roleName }

# try get role Id by name
$role = Get-MgDirectoryRole -Filter "RoleTemplateId eq '$($roleTemplate.Id)'"

# role does not exist
if ($null -eq $role)
{
	# create role from the template
	$role = New-MgDirectoryRole -RoleTemplateId $roleTemplate.Id

	Write-Host "Role [$roleName] created from the template.";
}

$assignments = Get-MgRoleManagementDirectoryRoleAssignment -All | Where-Object {($_.PrincipalId -eq $identityObjectId) -and ($_.RoleDefinitionId -eq $roleTemplate.Id)}

if ($null -ne $assignments)
{
	Write-Host "Role [$roleName] already assigned to Object with Id [$identityObjectId].";
}
else
{
	# add identity to the role
	New-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$identityObjectId"

	Write-Host "Role [$roleName] assigned to Object with Id [$identityObjectId]."
}
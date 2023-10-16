<#
	author: Stas Sultanov
	profile: https://www.linkedin.com/in/stas-sultanov
	contact: stas.sultanov@outlook.com
.DESCRIPTION
	Assign Entra role to specified identity
.NOTES
	Connect-AzAccount must be called before executing this script.
	Uses Mg library beta.
	Can be executed only by identity with one of the following roles:
	- "Global Administrator"
	- "Privileged Roles Administrator"
.PARAMETER roleName
	Name of the Entra Role
.PARAMETER identityObjectId
	ObjectId of the Identity
#>

param
(
	[Parameter(Mandatory = $true)] [System.String] $roleName,
	[Parameter(Mandatory = $true)] [System.String] $identityObjectId
)

# GOD DAMN Microsoft! can not do anything right!
# have to use beta, because Get-MgDirectoryRoleMember does not work as expected
Select-MgProfile -Name "beta"

# get access token
$accessToken = Get-AzAccessToken -ResourceTypeName MSGraph;

# secure access token
$accessTokenSecured = $accessToken.Token | ConvertTo-SecureString -AsPlainText -Force;

# connect to Graph
Connect-MgGraph -AccessToken $accessTokenSecured -NoWelcome;

# try get role by name
$role = Get-MgDirectoryRole | Where-Object { $_.displayName -eq $roleName }

# role does not exist
if ($null -eq $role)
{
	# get role template by name
	$roleTemplate = Get-MgDirectoryRoleTemplate | Where-Object { $_.displayName -eq $roleName }

	# create role from the template
	$role = New-MgDirectoryRole -RoleTemplateId $roleTemplate.Id

	Write-Output "Role [$roleName] created from the template.";
}

# get all role members
$roleMemberList = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All

# find identity within the role members list
$roleMember = $roleMemberList | Where-Object { $_.Id -match $identityObjectId }

if ($null -ne $roleMember)
{
	Write-Output "Identity with ObjectId [$identityObjectId] is already member of Role [$roleName].";
}
else
{
	# add identity to the role
	New-MgDirectoryRoleMemberByRef -DirectoryRoleId $role.Id -AdditionalProperties @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$identityObjectId" }

	Write-Output "Identity with ObjectId [$identityObjectId] is assigned with Role [$roleName]."
}
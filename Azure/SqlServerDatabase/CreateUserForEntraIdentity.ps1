<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Create SQL Server Database User for Identity within the Entra ID tenant.
.NOTES
	Copyright © 2023 Stas Sultanov.
.PARAMETER accessToken
	Bearer token to access an Azure SQL Server.
.PARAMETER databaseName
	Name of the Database within the Azure SQL Server.
.PARAMETER databaseRoles
	Collection of tha Database Roles to grant to the Identity.
.PARAMETER databaseUserName
	Name of the User to create or update for the Identity.
.PARAMETER identityObjectId
	ObjectId of the Identity within the Entra ID tenant.
.PARAMETER serverFQDN
	Fully Qualified Domain Name of the Azure SQL Server.
#>

param
(
	[parameter(Mandatory = $true)]	[String]	$accessToken,
	[Parameter(Mandatory = $true)]	[String]	$databaseName,
	[Parameter(Mandatory = $true)]	[String[]]	$databaseRoles,
	[Parameter(Mandatory = $true)]	[String]	$databaseUserName,
	[Parameter(Mandatory = $true)]	[String]	$identityObjectId,
	[Parameter(Mandatory = $true)]	[String]	$serverFQDN
)

# compose command
$command =
@"
	DROP USER IF EXISTS [$databaseUserName]

	CREATE USER [$databaseUserName] FROM EXTERNAL PROVIDER WITH OBJECT_ID='$identityObjectId'

"@

# add roles assignment to the command
foreach ($databaseRole in $databaseRoles)
{
	$command += "ALTER ROLE $databaseRole ADD MEMBER [$databaseUserName]`n"
}

# add go
$command += "GO"

# connect to the database and execute script
Invoke-Sqlcmd -AccessToken $accessToken -Database $databaseName -ServerInstance $serverFQDN -query $command
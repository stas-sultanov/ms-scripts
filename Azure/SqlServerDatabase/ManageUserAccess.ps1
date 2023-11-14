<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Set User access mode for the specified Sql Server Database.
.NOTES
	Copyright © 2023 Stas Sultanov.
.PARAMETER serverFQDN
	Fully Qualified Domain Name of the Sql Server.
.PARAMETER databaseName
	Azure Sql Database name within the Sql Server.
.PARAMETER action
	An action to perform.
	Restrict - the database can be access by the users with the one of the following role: db_owner, dbcreator.
	Release - the database can be access by any valid user.
#>

param
(
	[Parameter(Mandatory = $true)] [System.String] $serverFQDN,
	[Parameter(Mandatory = $true)] [System.String] $databaseName,
	[Parameter(Mandatory = $true)] [ValidateSet('Restrict', 'Release')] [System.String] $action
)

# compose command
$restrictCommand =
@"
	ALTER DATABASE [$databaseName] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE

	GO
"@

# compose command
$releaseCommand =
@"
	ALTER DATABASE [$databaseName] SET MULTI_USER

	GO
"@

$command = "";

switch -Exact ($action)
{
	"Restrict"
	{
		$command = $restrictCommand;
	}
	"Release"
	{
		$command = $releaseCommand;
	}
}

# Get Sql Server Access Token via Identity of the caller
$accessToken = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token

# Execute command
Invoke-Sqlcmd -ServerInstance $serverFQDN -Database $databaseName -AccessToken $accessToken -query $command
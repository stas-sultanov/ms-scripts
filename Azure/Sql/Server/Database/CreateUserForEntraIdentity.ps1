<#
	author: Stas Sultanov
	profile: https://www.linkedin.com/in/stas-sultanov
	contact: stas.sultanov@outlook.com
.DESCRIPTION
	Create SQL Server User for Identity within the Entra tenant
.PARAMETER serverFQDN
	Fully Qualified Domain Name of the Azure Sql Server
.PARAMETER databaseName
	Name of the Database within the Azure Sql Server
.PARAMETER databaseUserName
	Name of the User to create for the Identity
.PARAMETER databaseRoles
	Collection of tha Database Roles to grant to the Identity
.PARAMETER identityObjectId
	ObjectId of the Identity within the Entra tenant
#>

param
(
	[Parameter(Mandatory = $true)] [System.String]   $serverFQDN,
	[Parameter(Mandatory = $true)] [System.String]   $databaseName,
	[Parameter(Mandatory = $true)] [System.String]   $databaseUserName,
	[Parameter(Mandatory = $true)] [System.String[]] $databaseRoles,
	[Parameter(Mandatory = $true)] [System.String]   $identityObjectId
)

# Compose command
$command =
@"
	DROP USER IF EXISTS [$databaseUserName]

	CREATE USER [$databaseUserName] FROM EXTERNAL PROVIDER WITH OBJECT_ID='$identityObjectId'

"@

# Add roles assigment to the command
foreach ($databaseRole in $databaseRoles)
{
	$command += "ALTER ROLE $databaseRole ADD MEMBER [$databaseUserName]`n"
}

# Add go
$command += "GO"

# Get server access token via Managed Identity of the caller
$accessToken = (Get-AzAccessToken -ResourceUrl https://database.windows.net).Token

# Now that we have the token, we use it to connect to the database and execute script
Invoke-Sqlcmd -ServerInstance $serverFQDN -Database $databaseName -AccessToken $accessToken -query $command
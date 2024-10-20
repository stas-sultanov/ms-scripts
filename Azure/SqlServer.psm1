function Azure.SqlServer.Database.CreateUserForEntraIdentity
{
	<#
	.SYNOPSIS
		Create SQL Server Database User for Identity within the Entra ID tenant.
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
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[parameter(Mandatory = $true)] [String]   $accessToken,
		[Parameter(Mandatory = $true)] [String]   $databaseName,
		[Parameter(Mandatory = $true)] [String[]] $databaseRoles,
		[Parameter(Mandatory = $true)] [String]   $databaseUserName,
		[Parameter(Mandatory = $true)] [String]   $identityObjectId,
		[Parameter(Mandatory = $true)] [String]   $serverFQDN
	)
	process
	{
		# compose command
		$command =
@"
	DROP USER IF EXISTS [$databaseUserName]

	CREATE USER [$databaseUserName] FROM EXTERNAL PROVIDER WITH OBJECT_ID='$identityObjectId'

"@;

		# add roles assignment to the command
		foreach ($databaseRole in $databaseRoles)
		{
			$command += "ALTER ROLE $databaseRole ADD MEMBER [$databaseUserName]`n"
		}

		# add go
		$command += 'GO'

		# connect to the database and execute script
		Invoke-Sqlcmd -AccessToken $accessToken -Database $databaseName -ServerInstance $serverFQDN -query $command;
	}
}

Export-ModuleMember -Function Azure.SqlServer.Database.CreateUserForEntraIdentity;

function Azure.SqlServer.Database.ManageUserAccess
{
	<#
	.SYNOPSIS
		Set User access mode for the specified Sql Server Database.
	.PARAMETER accessToken
		Bearer token to access an Azure SQL Server.
	.PARAMETER action
		An action to perform.
		Restrict - the database can be access by the users with the one of the following role: db_owner, dbcreator.
		Release - the database can be access by any valid user.
	.PARAMETER databaseName
		Azure Sql Database name within the Sql Server.
	.PARAMETER serverFQDN
		Fully Qualified Domain Name of the Sql Server.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[parameter(Mandatory = $true)]
		[String] $accessToken,

		[Parameter(Mandatory = $true)]
		[ValidateSet('Restrict', 'Release')]
		[String] $action,

		[Parameter(Mandatory = $true)]
		[String] $databaseName,

		[Parameter(Mandatory = $true)]
		[String] $serverFQDN
	)
	process
	{
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

		$command = '';

		switch -Exact ($action)
		{
			'Restrict'
			{
				$command = $restrictCommand;
			}
			'Release'
			{
				$command = $releaseCommand;
			}
		}

		# connect to the database and execute script
		Invoke-Sqlcmd -AccessToken $accessToken -Database $databaseName -ServerInstance $serverFQDN -query $command;
	}
}

Export-ModuleMember -Function Azure.SqlServer.Database.ManageUserAccess;

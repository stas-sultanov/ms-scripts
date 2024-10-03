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
		[parameter(Mandatory = $true)]	[String]	$accessToken,
		[Parameter(Mandatory = $true)]	[ValidateSet('Restrict', 'Release')]	[String]	$action,
		[Parameter(Mandatory = $true)]	[String]	$databaseName,
		[Parameter(Mandatory = $true)]	[String]	$serverFQDN
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

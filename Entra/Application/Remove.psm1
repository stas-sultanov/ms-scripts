function Entra.Application.Remove
{
	<#
	.SYNOPSIS
		Remove the Application Registration from the Entra tenant.
	.DESCRIPTION
		Uses Microsoft.Graph Powershell module.
	.PARAMETER accessToken
		Bearer token to access MS Graph.
	.PARAMETER objectId
		Directory ObjectId of the Application Registration.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[parameter(Mandatory = $true)]	[String]		$objectId
	)
	process
	{
		<# implementation #>

		# connect to Graph
		Connect-MgGraph -AccessToken $accessToken -NoWelcome;

		# check if object exists
		$object = Get-MgApplication -Filter "Id eq '$objectId'";

		if ($null -eq $object)
		{
			Write-Host 'Application Registration does not exist';

			return;
		}

		Write-Host 'Application Registration Delete';

		# remove object
		Remove-MgApplication -ApplicationId $objectId;
	}
}

Export-ModuleMember -Function Entra.Application.Remove;

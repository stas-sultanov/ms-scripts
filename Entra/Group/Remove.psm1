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
		[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
		[parameter(Mandatory = $true)]	[String]		$groupObjectId
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
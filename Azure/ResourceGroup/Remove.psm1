function Azure.ResourceGroup.Remove
{
	<#
	.SYNOPSIS
		Remove the Azure resource group.
	.PARAMETER resourceGroupName
		The name of the resource group.
	.PARAMETER subscription
		The name or id of the Azure subscription.
	.PARAMETER tenant
		The domain name or id of Entra tenant.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[Parameter(Mandatory = $true)]	[String]	$resourceGroupName,
		[Parameter(Mandatory = $true)]	[String]	$subscription,
		[Parameter(Mandatory = $true)]	[String]	$tenant
	)
	process
	{
		# get verbose parameter value
		$isVerbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose'];

		# set context
		$null = Set-AzContext -Subscription $subscription -Tenant $tenant -Verbose:$isVerbose;

		# check if resource group exist
		$null = Get-AzResourceGroup -ErrorAction SilentlyContinue -ErrorVariable notExist -Name $resourceGroupName -Verbose:$isVerbose;

		if ($notExist)
		{
			return;
		}

		# remove group
		$null = Remove-AzResourceGroup -Name $resourceGroupName -Force;
	}
}

Export-ModuleMember -Function Azure.ResourceGroup.Remove;

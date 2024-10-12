function Azure.ResourceGroup.Provision
{
	<#
	.SYNOPSIS
		Provision resources within the Resource Group.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER deploymentModeComplete
		True if performe Complete deployment, otherwise Incremental.
	.PARAMETER deploymentName
		The name of the deployment.
	.PARAMETER location
		The location of the resource group.
	.PARAMETER resourceGroupName
		A name for the resource group
	.PARAMETER subscription
		The name or id of the Azure subscription.
	.PARAMETER tags
		The tags to put on the deployment.
	.PARAMETER templateFile
		The full path of a custom template file
	.PARAMETER templateParameters
		A hash table of template parameter names and values.
	.PARAMETER tenant
		The domain name or id of Entra tenant.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	.OUTPUTS
		System.Dictionary
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[Parameter(Mandatory = $true)]	[Boolean]	$deploymentModeComplete,
		[Parameter(Mandatory = $true)]	[String]	$deploymentName,
		[Parameter(Mandatory = $true)]	[String]	$location,
		[Parameter(Mandatory = $true)]	[String]	$resourceGroupName,
		[Parameter(Mandatory = $true)]	[String]	$subscription,
		[Parameter(Mandatory = $false)]	[Hashtable]	$tags = @{},
		[Parameter(Mandatory = $true)]	[String]	$templateFile,
		[Parameter(Mandatory = $false)]	[Object]	$templateParameters = @{},
		[Parameter(Mandatory = $true)]	[String]	$tenant
	)
	process
	{
		$isVerbose = $PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent;

		# set context
		$null = Set-AzContext -Subscription $subscription -Tenant $tenant -Verbose:($isVerbose);

		# check if resource group exist
		$null = Get-AzResourceGroup -ErrorAction SilentlyContinue -ErrorVariable notExist -Name $resourceGroupName -Verbose:($isVerbose);

		if ($notExist)
		{
			# create resource group
			$null = New-AzResourceGroup -Force -Location $location -Name $resourceGroupName -Verbose:($isVerbose);
		}

		# provision resources
		$provisionResult = New-AzResourceGroupDeployment `
			-Force `
			-Mode ($deploymentModeComplete ? 1 : 0) `
			-Name $deploymentName `
			-ResourceGroupName $resourceGroupName `
			-Tag $tags `
			-TemplateFile $templateFile `
			-TemplateParameterObject $templateParameters `
			-Verbose:($isVerbose);

		# return result
		return $provisionResult.Outputs;
	}
}

Export-ModuleMember -Function Azure.ResourceGroup.Provision;

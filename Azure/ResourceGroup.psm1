function Azure.ResourceGroup.Provision
{
	<#
	.SYNOPSIS
		Provision resources within the Resource Group.
	.DESCRIPTION
		Can be executed by Identity which has Power Platform Administrator role within Entra.
	.PARAMETER deploymentModeComplete
		True if perform Complete deployment, otherwise Incremental.
	.PARAMETER deploymentName
		The name of the deployment.
	.PARAMETER location
		The location of the resource group.
	.PARAMETER resourceGroupName
		A name for the resource group.
	.PARAMETER subscription
		The name or id of the Azure subscription.
	.PARAMETER templateFile
		The full path of a custom template file
	.PARAMETER templateParameters
		A hash table of template parameter names and values.
	.PARAMETER tenant
		The domain name or id of Entra tenant.
	.OUTPUTS
		System.IDictionary
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	[CmdletBinding(DefaultParameterSetName = 'User')]
	param
	(
		[Parameter(Mandatory = $true)]  [Boolean] $deploymentModeComplete,
		[Parameter(Mandatory = $true)]  [String]  $deploymentName,
		[Parameter(Mandatory = $true)]  [String]  $location,
		[Parameter(Mandatory = $true)]  [String]  $resourceGroupName,
		[Parameter(Mandatory = $true)]  [String]  $subscription,
		[Parameter(Mandatory = $true)]  [String]  $templateFile,
		[Parameter(Mandatory = $false)] [Object]  $templateParameters = @{},
		[Parameter(Mandatory = $true)]  [String]  $tenant
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
			# create resource group
			$null = New-AzResourceGroup -Force -Location $location -Name $resourceGroupName -Verbose:$isVerbose;
		}

		# provision resources
		$provisionResult = New-AzResourceGroupDeployment `
			-Force `
			-Mode ($deploymentModeComplete ? 1 : 0) `
			-Name $deploymentName `
			-ResourceGroupName $resourceGroupName `
			-TemplateFile $templateFile `
			-TemplateParameterObject $templateParameters `
			-Verbose:$isVerbose;

		# return result
		return $provisionResult.Outputs;
	}
}

Export-ModuleMember -Function Azure.ResourceGroup.Provision;

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
		[Parameter(Mandatory = $true)] [String] $resourceGroupName,
		[Parameter(Mandatory = $true)] [String] $subscription,
		[Parameter(Mandatory = $true)] [String] $tenant
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

function Azure.DataFactory.SetTriggerState
{
	<#
	.SYNOPSIS
		Stop all triggers in specified Azure DataFactory instance.
	.PARAMETER dataFactoryResourceId
		Id of the DataFactory Resource.
	.PARAMETER action
		An action to perform.
		Start - start trigger(s).
		Stop - stop trigger(s).
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[Parameter(Mandatory = $true)] [System.String] $dataFactoryResourceId,
		[Parameter(Mandatory = $true)] [ValidateSet('Start', 'Stop')] [System.String] $action
	)
	process
	{
		$factoryResourceIdSplit = $dataFactoryResourceId.Split('/');

		$resourceGroupName = $factoryResourceIdSplit[4];

		$factoryName = $factoryResourceIdSplit[8];

		# get all triggers
		$triggers = Get-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $factoryName

		foreach ($trigger in $triggers)
		{
			switch -Exact ($action)
			{
				'Start'
				{
					if ($trigger.RuntimeState -eq 'Started')
					{
						continue; 
					}

					# start trigger
					Start-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $factoryName -Name $trigger.name -Force

					Write-Information "DataFactory [$factoryName] Trigger [$($trigger.Name)] Started"
				}
				'Stop'
				{
					if ($trigger.RuntimeState -eq 'Stopped')
					{
						continue; 
					}

					# stop trigger
					Stop-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $factoryName -Name $trigger.name -Force

					Write-Information "DataFactory [$factoryName] Trigger [$($trigger.Name)] Stopped"
				}
			}
		}
	}
}

Export-ModuleMember -Function Azure.DataFactory.SetTriggerState;

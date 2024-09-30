<#
	author:		Stas Sultanov
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Stop all triggers in specified Azure DataFactory instance.
.NOTES
	Copyright © 2024 Stas Sultanov.
.PARAMETER dataFactoryResourceId
	Id of the DataFactory Resource.
.PARAMETER action
	An action to perform.
	Start - start trigger(s).
	Stop - stop trigger(s).
#>

param
(
	[Parameter(Mandatory = $true)] [System.String] $dataFactoryResourceId,
	[Parameter(Mandatory = $true)] [ValidateSet('Start', 'Stop')] [System.String] $action
)

$factoryResourceIdSplit = $dataFactoryResourceId.Split('/');

$resourceGroupName = $factoryResourceIdSplit[4];

$factoryName = $factoryResourceIdSplit[8];

# get all triggers
$triggers = Get-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $factoryName

foreach ($trigger in $triggers)
{
	switch -Exact ($action)
	{
		"Start"
		{
			if ($trigger.RuntimeState -eq "Started") { continue; }

			# start trigger
			Start-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $factoryName -Name $trigger.name -Force

			Write-Information "DataFactory [$factoryName] Trigger [$($trigger.Name)] Started"
		}
		"Stop"
		{
			if ($trigger.RuntimeState -eq "Stopped") { continue; }

			# stop trigger
			Stop-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $factoryName -Name $trigger.name -Force

			Write-Information "DataFactory [$factoryName] Trigger [$($trigger.Name)] Stopped"
		}
	}
}

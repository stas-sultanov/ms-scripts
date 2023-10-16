<#
	author: Stas Sultanov
	profile: https://www.linkedin.com/in/stas-sultanov
	contact: stas.sultanov@outlook.com
.DESCRIPTION
	Stop all triggers in specified Azure DataFactory instance.
.PARAMETER dataFactoryResourceId
	Id of the DataFactory Resource
.PARAMETER action
	An action to perform.
	Start - start trigger(s)
	Stop - stop trigger(s)
#>

param
(
	[Parameter(Mandatory = $true)] [System.String] $dataFactoryResourceId,
	[Parameter(Mandatory = $true)] [ValidateSet('Start', 'Stop')] [System.String] $action
)

$factoryResourceIdSplit = $dataFactoryResourceId.Split('/');

$resourcGroupName = $factoryResourceIdSplit[4];

$factoryName = $factoryResourceIdSplit[8];

# get all triggers
$triggers = Get-AzDataFactoryV2Trigger -ResourceGroupName $resourcGroupName -DataFactoryName $factoryName

foreach ($trigger in $triggers)
{
	switch -Exact ($action)
	{
		"Start"
		{
			if ($trigger.RuntimeState -eq "Started") { continue; }

			# stop trigger
			Start-AzDataFactoryV2Trigger -ResourceGroupName $resourcGroupName -DataFactoryName $factoryName -Name $trigger.name -Force

			Write-Host "DataFactory [$factoryName] Trigger [$($trigger.Name)] Started"
		}
		"Stop"
		{
			if ($trigger.RuntimeState -eq "Stopped") { continue; }

			# stop trigger
			Stop-AzDataFactoryV2Trigger -ResourceGroupName $resourcGroupName -DataFactoryName $factoryName -Name $trigger.name -Force

			Write-Host "DataFactory [$factoryName] Trigger [$($trigger.Name)] Stopped"
		}
	}
}

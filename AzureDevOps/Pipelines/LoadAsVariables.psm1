using namespace System.Collections.Generic;
using namespace System.Text.Json;

function Flatten
{
	param
	(
		[Dictionary[String, String]] $result,
		[JsonElement] $rootElement,
		[String] $prefix,
		[String] $delimiter
	)
	process
	{
		$rootPrefix = [string]::IsNullOrEmpty($prefix) ? '' : $prefix + $delimiter;

		if ($rootElement.ValueKind -eq [JsonValueKind]::Array)
		{
			$index = 0;

			foreach ($item in $rootElement.EnumerateArray())
			{
				$itemPrefix = $rootPrefix + $index.ToString();

				# recursion
				Flatten $result $item $itemPrefix $delimiter;

				$index++;
			}

			return;
		}

		if ($rootElement.ValueKind -eq [JsonValueKind]::Object)
		{
			foreach ($item in $rootElement.EnumerateObject())
			{
				$itemPrefix = $rootPrefix + $item.Name;

				# recursion
				Flatten $result $item.Value $itemPrefix $delimiter;
			}

			return;
		}

		$result.Add($prefix, $rootElement.ToString());
	}
}

function Azure.DevOps.LoadAsVariables
{
	<#
	.SYNOPSIS
		Load file in JSON format as Azure DevOps Pipeline variables.
	.PARAMETER fileName
		Name of the file to load.
	.PARAMETER delimiter
		Delimiter to use for variable name generation.
	.PARAMETER prefix
		Prefix to use for variable name generation.
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[parameter(Mandatory = $True)] [String] $fileName,
		[String] $delimiter = '',
		[String] $prefix = $null
	)
	process
	{
		# get file content as string
		$fileContent = Get-Content $fileName | Out-String;

		# deserialize document
		$document = [JsonSerializer]::Deserialize($fileContent, [JsonDocument]);

		$documentAsFlatDictionary = New-Object Dictionary"[String,String]";

		# flatten document
		Flatten $documentAsFlatDictionary $document.RootElement $prefix $delimiter;

		# load key value pairs
		foreach ($item in $documentAsFlatDictionary.GetEnumerator())
		{
			$key = $item.Key;

			$value = $item.Value;

			Write-Host "##vso[task.SetVariable variable=${key};]${value}";

			Write-Information "Loaded variable ${key}";
		}
	}
}

Export-ModuleMember -Function Azure.DevOps.LoadAsVariables;

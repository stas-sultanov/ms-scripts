<#
	author: Stas Sultanov
	profile: https://www.linkedin.com/in/stas-sultanov
	contact: stas.sultanov@outlook.com
.DESCRIPTION
	Loads file in JSON format as Azure DevOps Pipeline variables.
.PARAMETER fileName
	Name of the file to load.
.PARAMETER delimiter
	Delimeter to use for variable name generation.
.PARAMETER preix
	Prefix to use for variable name generation.
#>

using namespace System.Collections.Generic;
using namespace System.Text.Json;

param
(
	[parameter(Mandatory = $True)] [String] $fileName,
	[String] $delimiter = "",
	[String] $prefix = $null
)

function Flatten
{
	param
	(
		[Dictionary[String, String]] $result,
		[JsonElement] $rootElement,
		[String] $prefix,
		[String] $delimiter
	)

	$rootPrefix = [string]::IsNullOrEmpty($prefix) ? "" : $prefix + $delimiter;

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

# get file content as string
$fileContent = Get-Content $fileName | out-string;

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

	Write-Host "##vso[task.setvariable variable=${key};]${value}";

	Write-Output "Loaded variable ${key}";
}
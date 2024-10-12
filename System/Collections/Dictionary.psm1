using namespace System;
using namespace System.Collections;
using namespace System.Collections.Specialized;

function Dictionary.Merge
{
	<#
	.SYNOPSIS
		Merge Hashtables.
	.PARAMETER first
		Basic layer.
	.PARAMETER second
		Next layer
	.OUTPUTS
		[OrderedDictionary] that contains values from first and second
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[IDictionary] $first,
		[IDictionary] $second
	)
	process
	{
		if ($null -eq $first)
		{
			throw [ArgumentNullException]::new('first');
		}

		if ($null -eq $second)
		{
			throw [ArgumentNullException]::new('second');
		}

		# clone for idempotence
		$result = [OrderedDictionary]::new();

		foreach ($key in $first.Keys)
		{
			$result[$key] = $first[$key];
		}

		foreach ($key in $second.Keys)
		{
			$secondValue = $second[$key];

			# check if first does not contain the key or key has null value
			if (!$first.Contains($key) -or ($null -eq $result[$key]))
			{
				# add key-value from second to first
				$result[$key] = $secondValue;

				continue;
			}

			$firstValue = $first[$key];

			# check if both values are IDictionary
			if (($firstValue -is [IDictionary]) -and ($secondValue -is [IDictionary]))
			{
				$result[$key] = Dictionary.Merge -first $firstValue -second $secondValue;

				continue;
			}

			if (($firstValue -is [Array]) -and ($secondValue -is [Array]))
			{
				$result[$key] = [Array] $firstValue + [Array] $secondValue;

				continue;
			}

			$firstValueType = $firstValue.GetType();
			$secondValueType = $secondValue.GetType();

			if ($firstValueType -ne $secondValueType)
			{
				throw "Different value types for key = $key : $firstValueType vs $secondValueType.";
			}

			# just override the value
			$result[$key] = $secondValue;
		}

		# Union both sets
		return $result;
	}
}

Export-ModuleMember -Function Dictionary.Merge;
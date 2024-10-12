using namespace System;
using namespace System.Collections;

function Merge-Hashtable
{
	<#
	.SYNOPSIS
		Merge Hashtables.
	.PARAMETER first
		Basic layer.
	.PARAMETER second
		Next layer
	.OUTPUTS
		[Hashtable] that contains values from first and second
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[Hashtable] $first,
		[Hashtable] $second
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
		$result = $first.Clone();

		foreach ($key in $second.Keys)
		{
			$secondValue = $second[$key];

			# check if first does not contain the key or key has null value
			if (!$first.ContainsKey($key) -or ($null -eq $result[$key]))
			{
				# add key-value from second to first
				$result[$key] = $secondValue;

				continue;
			}

			$firstValue = $first[$key];

			$firstValueType = $firstValue.GetType();
			$secondValueType = $secondValue.GetType();

			if ($firstValueType -ne $secondValueType )
			{
				throw "Different value types for key = $key : $firstValueType vs $secondValueType.";
			}

			if ($firstValue -is [Hashtable])
			{
				$result[$key] = Merge-HashTable -first $firstValue -second $secondValue;

				continue;
			}

			if ($firstValue -is [Array])
			{
				$result[$key] = [Array] $firstValue + [Array] $secondValue;

				continue;
			}

			# just override the value
			$result[$key] = $secondValue;
		}

		# Union both sets
		return $result;
	}
}

Export-ModuleMember -Function Merge-Hashtable;
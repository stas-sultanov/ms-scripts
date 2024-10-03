function Merge-HashTable
{
	<#
	.SYNOPSIS
		Merge Hashtables.
	.PARAMETER layer0
		Basic layer.
	.PARAMETER layer1
		Next layer
	.OUTPUTS
		hashtable
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[hashtable] $layer0,
		[hashtable] $layer1
	)
	process
	{
		# clone for idempotence
		$result = $layer0.Clone();

		foreach ($key in $layer1.Keys)
		{
			# check if first contains the key
			if (!$layer0.ContainsKey($key))
			{
				# add key-value from second to first
				$result[$key] = $layer1[$key];

				continue;
			}

			$layer0Value = $layer0[$key];
			$layer1Value = $layer1[$key];

			if ($layer0Value.GetType() -ne $layer1Value.GetType())
			{
				throw "Different types for key = $key";
			}

			if ($layer0Value -is [hashtable])
			{
				$result[$key] = Merge-HashTable -first $layer0Value -second $layer1Value;

				continue;
			}

			if ($layer0Value -is [array])
			{
				$result[$key] = [array] $layer0Value  + [array] $layer1Value;

				continue;
			}

			# just override the value
			$result[$key] = $layer1Value;
		}

		# Union both sets
		return $result;
	}
}

Export-ModuleMember -Function Merge-HashTable;
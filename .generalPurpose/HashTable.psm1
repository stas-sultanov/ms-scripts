function Merge-HashTable
{
	param
	(
		[hashtable] $first,
		[hashtable] $second
	)
	process
	{
		# clone for idempotence
		$result = $first.Clone();

		foreach ($key in $second.Keys)
		{
			# check if first contains the key
			if (!$first.ContainsKey($key))
			{
				# add key-value from second to first
				$result[$key] = $second[$key];

				continue;
			}

			$firstValue = $first[$key];
			$secondValue = $second[$key];

			if ($firstValue.GetType() -ne $second[$key].GetType())
			{
				throw "Different types for key = $key";
			}

			if ($firstValue -is [hashtable])
			{
				$result[$key] = Merge-HashTable -first $firstValue -second $secondValue;

				continue;
			}

			# just override the value
			$result[$key] = $secondValue;
		}

		# Union both sets
		return $result;
	}
}

Export-ModuleMember -Function Merge-HashTable;
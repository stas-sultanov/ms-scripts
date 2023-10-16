<#
	author: Stas Sultanov,
	contact: stas.sultanov@outlook.com,
	description: Enable HTTPS
#>

param
(
	[Parameter(Mandatory = $true)]  [string] $resourceGroup # Name of the Resource Group
)

# List CDN profile names
$profileNameList = $(az cdn profile list -g $resourceGroup --query "[].name") | ConvertFrom-Json;

# for each profile in profiles list
foreach ($profileName in $profileNameList)
{
	# list endpoints
	$endpointNameList = $(az cdn endpoint list -g $resourceGroup --profile-name $profileName --query "[].name") | ConvertFrom-Json;

	# for each endpoint in endpoints list
	foreach ($endpointName in $endpointNameList)
	{
		# list custom domains
		$customDomainNameList = $(az cdn custom-domain list -g $resourceGroup --profile-name $profileName --endpoint-name $endpointName --query "[].name") | ConvertFrom-Json
	
		# for each custom domain in custom domains list
		foreach ($customDomainName in $customDomainNameList)
		{
			# enable https for custom domain
			az cdn custom-domain enable-https -g $resourceGroup --profile-name $profileName --endpoint-name $endpointName --name $customDomainName
		}
	}
}
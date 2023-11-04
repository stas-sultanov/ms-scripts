<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Enable HTTPS for all CDN profiles.
.NOTES
	Copyright © 2023 Stas Sultanov
.PARAMETER resourceGroupName
	Name of the resource group.
#>

param
(
	[Parameter(Mandatory = $true)]  [string] $resourceGroupName # Name of the Resource Group
)

# List CDN profile names
$profileNameList = $(az cdn profile list -g $resourceGroupName --query "[].name") | ConvertFrom-Json;

# for each profile in profiles list
foreach ($profileName in $profileNameList)
{
	# list endpoints
	$endpointNameList = $(az cdn endpoint list -g $resourceGroupName --profile-name $profileName --query "[].name") | ConvertFrom-Json;

	# for each endpoint in endpoints list
	foreach ($endpointName in $endpointNameList)
	{
		# list custom domains
		$customDomainNameList = $(az cdn custom-domain list -g $resourceGroupName --profile-name $profileName --endpoint-name $endpointName --query "[].name") | ConvertFrom-Json
	
		# for each custom domain in custom domains list
		foreach ($customDomainName in $customDomainNameList)
		{
			# enable https for custom domain
			az cdn custom-domain enable-https -g $resourceGroupName --profile-name $profileName --endpoint-name $endpointName --name $customDomainName
		}
	}
}
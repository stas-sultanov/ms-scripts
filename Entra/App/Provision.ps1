<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Provision an Application Registration within the Entra ID tenant.
.DESCRIPTION
	Script assumes that names of the applications are unique within the Entra ID tenant.
	Connect-AzAccount must be called before executing this script.
	Uses Mg library v1, also for Graph direct API calls.
.NOTES
	Copyright © 2023 Stas Sultanov
.PARAMETER appName
	Name of the Application.
.PARAMETER manifestFileName
	Name of the Manifest file, including path.
.PARAMETER logoFileName
	Name of the Logo file, including path.
.OUTPUTS
	System.Object
	On object with following fields:
		- ClientId
		- IdentifierUris
		- ObjectId
		- Secrets
#>

using namespace Microsoft.Graph.PowerShell.Models;

param
(
	[parameter(Mandatory = $true)] [String] $appName,
	[parameter(Mandatory = $true)] [String] $manifestFileName,
	[parameter(Mandatory = $true)] [String] $logoFileName
)

<# implementation #>

# get access token
$accessToken = Get-AzAccessToken -ResourceTypeName MSGraph;

# secure access token
$accessTokenSecured = $accessToken.Token | ConvertTo-SecureString -AsPlainText -Force;

# connect to Graph
Connect-MgGraph -AccessToken $accessTokenSecured -NoWelcome;

<# read manifest file #>

$manifest = Get-Content $manifestFileName | out-string | ConvertFrom-Json -AsHashtable;

<# get or create application #>

if ([string]::IsNullOrEmpty($manifest.Id))
{
	# get all applications by name
	$app = Get-MgApplication -Filter "DisplayName eq '$appName'";

	# check if there is more then one application
	if ($app -is [array])
	{
		throw "Directory query returned more than one App Registration with DisplayName [$appName].";
	}
}
else
{
	# get application
	$app = Get-MgApplicationByAppId -AppId $manifest.Id;
}

# check if app not exist
if ($null -eq $app)
{
	Write-Information "App Registration Create";

	# create new app registration
	if ([string]::IsNullOrEmpty($manifest.Id))
	{
		$app = New-MgApplication -DisplayName $appName;
	}
	else
	{
		$app = New-MgApplication -AppId $manifest.Id -DisplayName $appName;
	}
}
else
{
	Write-Information "App Registration Update";
}

<# provision properties #>

# get MicrosoftGraphRequiredResourceAccess[]
$requiredResourceAccess = $manifest.RequiredResourceAccess | ForEach-Object { [MicrosoftGraphRequiredResourceAccess]::DeserializeFromDictionary($_) };

# get MicrosoftGraphOptionalClaims
$optionalClaims = [MicrosoftGraphOptionalClaims]::DeserializeFromDictionary($manifest.OptionalClaims);

Write-Information "App Registration Update Notes";
Write-Information "App Registration Update OptionalClaims";
Write-Information "App Registration Update RequiredResourceAccess";
Write-Information "App Registration Update SignInAudience";

Update-MgApplication -ApplicationId $app.Id `
	-Notes $manifest.Notes `
	-OptionalClaims $optionalClaims `
	-RequiredResourceAccess $requiredResourceAccess `
	-SignInAudience $manifest.SignInAudience;

<# provision IdentifierUris #>

Write-Information "App Registration Update IdentifierUris";

$identifierUris = [array] ($manifest.IdentifierUris | ForEach-Object { $_ -f $app.AppId });

Update-MgApplication -ApplicationId $app.Id -IdentifierUris $identifierUris;

<# provision PublisherDomain #>

if (![string]::IsNullOrEmpty($manifest.PublisherDomain))
{
	Write-Information "App Registration Update PublisherDomain";

	Update-MgApplication -ApplicationId $app.Id -PublisherDomain $manifest.PublisherDomain
}

<# provision Api #>

$api = [MicrosoftGraphApiApplication]::DeserializeFromDictionary($manifest.Api);

# PreAuthorizedApplications requires Oauth2PermissionScopes to exist already
$apiWithoutPreAuthorizedApplications = [MicrosoftGraphApiApplication]::DeserializeFromDictionary($manifest.Api);
$apiWithoutPreAuthorizedApplications.PreAuthorizedApplications = $null;

Write-Information "App Registration Update Api";

Update-MgApplication -ApplicationId $app.Id -Api $apiWithoutPreAuthorizedApplications

Update-MgApplication -ApplicationId $app.Id -Api $api

<# provision AppRoles #>

$appRoles = $manifest.AppRoles | ForEach-Object { [MicrosoftGraphAppRole]::DeserializeFromDictionary($_) };

Write-Information "App Registration Update AppRoles";

Update-MgApplication -ApplicationId $app.Id -AppRoles $appRoles

<# provision Logo #>

# check if logo file name was specified
if (![string]::IsNullOrEmpty($logoFileName))
{
	Write-Information "App Registration Update Logo";

	# there is a bug in Set-MgApplicationLogo, this is why we call raw api
	Invoke-GraphRequest -Method PUT -Uri "https://graph.microsoft.com/v1.0/applications/$($app.Id)/logo" -InputFilePath $logoFileName -ContentType 'image/*';
}

<# provision Owners #>

# get owners from manifest
$ownerIdList = @();

if ($null -ne $manifest.Owners)
{
	$ownerIdList = $manifest.Owners | ForEach-Object { [MicrosoftGraphDirectoryObject]::DeserializeFromDictionary($_) } | Select-Object -ExpandProperty Id;
}

# get existing owners
$existingOwnerIdList = Get-MgApplicationOwner -ApplicationId $app.Id | Select-Object -ExpandProperty Id;

# get owners to add by excluding existing owners from specified in manifest
$toAddOwnerIdList = $ownerIdList | Where-Object { $_ -notin $existingOwnerIdList };

foreach ($ownerId in $toAddOwnerIdList)
{
	Write-Information "App Registration Add Owner [$ownerId]";

	# add owner
	New-MgApplicationOwnerByRef -ApplicationId $app.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$ownerId"
}

# get objectId of the service principal that executes this script
$currentPrincipalObjectId = (Get-AzADServicePrincipal -ApplicationId $accessToken.UserId).Id;

# get owners to remove, excluding current identity
$toRemoveOwnerIdList = $existingOwnerIdList | Where-Object { ($_ -ne $currentPrincipalObjectId) -and ($_ -notin $ownerIdList) };

foreach ($ownerId in $toRemoveOwnerIdList)
{
	Write-Information "App Registration Remove Owner [$ownerId]";

	# remove owner
	Remove-MgApplicationOwnerByRef -ApplicationId $app.Id -DirectoryObjectId $ownerId;
}

<# provision PasswordCredentials #>

# there is a no Get-MgApplicationPasswordCredentials, this is why we call raw api
$existingPasswordCredentialList = [IMicrosoftGraphPasswordCredential[]](Invoke-GraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$($app.Id)/passwordCredentials").Value;

# remove all existing passwords
foreach ($passwordCredential in $existingPasswordCredentialList)
{
	Write-Information "App Registration Remove Secret [$($passwordCredential.DisplayName)]";

	Remove-MgApplicationPassword -ApplicationId $app.Id -KeyId $passwordCredential.KeyId;
}

# get MicrosoftGraphPasswordCredential
$passwordCredentialList = $manifest.PasswordCredentials | ForEach-Object { [MicrosoftGraphPasswordCredential]::DeserializeFromDictionary($_) };

# add new secrets
$secrets = @{};

foreach ($passwordCredential in $passwordCredentialList)
{
	Write-Information "App Registration Add Secret [$($passwordCredential.DisplayName)]";

	#add password
	$newPasswordCredential = Add-MgApplicationPassword -ApplicationId $app.Id -PasswordCredential $passwordCredential;

	$secrets[$newPasswordCredential.DisplayName] = $newPasswordCredential.SecretText;
};

<# provision Web #>

Write-Information "App Registration Update Web";

$web = [MicrosoftGraphWebApplication]::DeserializeFromDictionary($manifest.Web);

Update-MgApplication -ApplicationId $app.Id -Web $web;

<# return result #>

return @{
	ClientId = $app.AppId
	IdentifierUris = $identifierUris
	ObjectId = $app.Id
	Secrets = $secrets
};
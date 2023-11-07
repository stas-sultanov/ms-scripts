<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Provision an Application Registration within the Entra ID tenant.
.DESCRIPTION
	Script assumes that names of the applications are unique within the Entra ID tenant.
	Uses Microsoft.Graph Powershell module.
.NOTES
	Copyright © 2023 Stas Sultanov
.PARAMETER accessToken
	Bearer token to access MS Graph.
.PARAMETER logoFileName
	Name of the Logo file, including path.
.PARAMETER manifestFileName
	Name of the Manifest file, including path.
.PARAMETER name
	Name of the Application.
.OUTPUTS
	System.Object
	On object with following fields:
		- ClientId:System.Guid
		- IdentifierUris
		- ObjectId:System.Guid
		- Secrets
#>

using namespace Microsoft.Graph.PowerShell.Models;

param
(
	[parameter(Mandatory = $true)]	[String]	$accessToken,
	[parameter(Mandatory = $true)]	[String]	$identityObjectId,
	[parameter(Mandatory = $true)]	[String]	$logoFileName,
	[parameter(Mandatory = $true)]	[String]	$manifestFileName,
	[parameter(Mandatory = $true)]	[String]	$name
)

<# implementation #>

# secure access token
$accessTokenSecured = $accessToken | ConvertTo-SecureString -AsPlainText -Force;

# connect to Graph
Connect-MgGraph -AccessToken $accessTokenSecured -NoWelcome;

<# read manifest file #>

$manifest = Get-Content $manifestFileName | out-string | ConvertFrom-Json -AsHashtable;

<# get or create application #>

# get all Applications Registrations with DisplayName eq specified
$app = Get-MgApplication -Filter "DisplayName eq '$name'";

# check if there is more then one app registration
if ($app -is [array])
{
	throw "Directory query returned more than one App Registration with DisplayName eq [$name].";
}

# check if app not exist
if ($null -eq $app)
{
	Write-Information "App Registration Create";

	# create new app registration
	$app = New-MgApplication -DisplayName $name;
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

# get owners to add, by excluding existing owners from specified in manifest
$toAddOwnerIdList = $ownerIdList | Where-Object { $_ -notin $existingOwnerIdList };

foreach ($ownerId in $toAddOwnerIdList)
{
	Write-Information "App Registration Add Owner [$ownerId]";

	# add owner
	New-MgApplicationOwnerByRef -ApplicationId $app.Id -OdataId "https://graph.microsoft.com/v1.0/directoryObjects/$ownerId"
}

# get owners to remove, excluding current identity
$toRemoveOwnerIdList = $existingOwnerIdList | Where-Object { ($_ -ne $identityObjectId) -and ($_ -notin $ownerIdList) };

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
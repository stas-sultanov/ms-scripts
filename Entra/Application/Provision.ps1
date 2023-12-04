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
	Copyright © 2023 Stas Sultanov.
.PARAMETER accessToken
	Bearer token to access MS Graph.
.PARAMETER identityObjectId
	ObjectId of the Identity which calls this script.
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
	[parameter(Mandatory = $true)]	[SecureString]	$accessToken,
	[parameter(Mandatory = $true)]	[String]		$identityObjectId,
	[parameter(Mandatory = $true)]	[String]		$logoFileName,
	[parameter(Mandatory = $true)]	[String]		$manifestFileName,
	[parameter(Mandatory = $true)]	[String]		$name
)

<# implementation #>

function CreateApplication {
	param
	(
		[parameter(Mandatory = $true)] [IMicrosoftGraphApplication] $desiredState
	)

	# create construction object
	$body = [IMicrosoftGraphApplication] @{
		AccessTokenAcceptedVersion = $desiredState.AccessTokenAcceptedVersion
		Api                        = $desiredState.Api
		AppRoles                   = $desiredState.AppRoles
		DisplayName                = $name
		Notes                      = $desiredState.Notes
		OptionalClaims             = $desiredState.OptionalClaims
		RequiredResourceAccess     = $desiredState.RequiredResourceAccess
		SignInAudience             = $desiredState.SignInAudience
		Web                        = $desiredState.Web
	}

	# create new app registration
	$result = New-MgApplication -BodyParameter $body;

	return $result;
}

function UpdateApplication {
	param
	(
		[parameter(Mandatory = $true)] [IMicrosoftGraphApplication] $desiredState,
		[parameter(Mandatory = $true)] [IMicrosoftGraphApplication] $currentState
	)

	$body = [IMicrosoftGraphApplication] @{
		AccessTokenAcceptedVersion = $desiredState.AccessTokenAcceptedVersion
		Api                        = $desiredState.Api
		AppRoles                   = $desiredState.AppRoles
		Notes                      = $desiredState.Notes
		OptionalClaims             = $desiredState.OptionalClaims
		RequiredResourceAccess     = $desiredState.RequiredResourceAccess
		SignInAudience             = $desiredState.SignInAudience
		Web                        = $desiredState.Web
	}

	Update-MgApplication -ApplicationId $currentState.Id -BodyParameter $body
}

# connect to Graph
Connect-MgGraph -AccessToken $accessToken -NoWelcome;

# get Graph Endpoint
$graphEndpoint = ( Get-MgEnvironment -Name ( Get-MgContext ).Environment ).GraphEndpoint;

<# get or create application #>

# get all Applications Registrations with DisplayName eq specified
$currentState = Get-MgApplication -Filter "DisplayName eq '$name'";

# check if there is more then one app registration
if ($currentState -is [array]) {
	throw "Directory query returned more than one App Registration with DisplayName eq [$name].";
}

<# read manifest file #>

# load manifest content as hashtable
$manifestContent = Get-Content $manifestFileName | out-string | ConvertFrom-Json -AsHashtable;

# deserialize
$desiredState = [MicrosoftGraphApplication]::DeserializeFromDictionary( $manifestContent );

# check if app not exist
if ($null -eq $currentState) {
	Write-Host "App Registration Create";

	$currentState = CreateApplication $desiredState;
}
else {
	Write-Host "App Registration Update";

	UpdateApplication $desiredState $currentState
}

# update identifier uris
$identifierUris = [array] ($desiredState.IdentifierUris | ForEach-Object { $_.Replace('{Id}', $currentState.Id) });

Update-MgApplication -ApplicationId $currentState.Id -IdentifierUris $identifierUris;

<# provision PublisherDomain #>

if (![string]::IsNullOrEmpty($desiredState.PublisherDomain)) {
	Write-Host "App Registration Update PublisherDomain";

	Update-MgApplication -ApplicationId $currentState.Id -PublisherDomain $desiredState.PublisherDomain
}

<# provision Logo #>

# check if logo file name was specified
if (![string]::IsNullOrEmpty($logoFileName)) {
	Write-Host "App Registration Update Logo";

	# there is a bug in Set-MgApplicationLogo, this is why we call raw api
	Invoke-GraphRequest -Method PUT -Uri "$graphEndpoint/v1.0/applications/$($currentState.Id)/logo" -InputFilePath $logoFileName -ContentType 'image/*';
}

<# provision Owners #>

# get owners from manifest
$ownerIdList = @();

if ($null -ne $desiredState.Owners) {
	$ownerIdList = $desiredState.Owners | Select-Object -ExpandProperty Id;
}

# get existing owners
$existingOwnerIdList = Get-MgApplicationOwner -ApplicationId $currentState.Id | Select-Object -ExpandProperty Id;

# get owners to add, by excluding existing owners from specified in manifest
$toAddOwnerIdList = $ownerIdList | Where-Object { $_ -notin $existingOwnerIdList };

foreach ($ownerId in $toAddOwnerIdList) {
	Write-Host "App Registration Add Owner [$ownerId]";

	# add owner
	New-MgApplicationOwnerByRef -ApplicationId $currentState.Id -OdataId "$graphEndpoint/v1.0/directoryObjects/$ownerId"
}

# get owners to remove, excluding current identity
$toRemoveOwnerIdList = $existingOwnerIdList | Where-Object { ($_ -ne $identityObjectId) -and ($_ -notin $ownerIdList) };

foreach ($ownerId in $toRemoveOwnerIdList) {
	Write-Host "App Registration Remove Owner [$ownerId]";

	# remove owner
	Remove-MgApplicationOwnerByRef -ApplicationId $currentState.Id -DirectoryObjectId $ownerId;
}

<# provision PasswordCredentials #>

# there is a no Get-MgApplicationPasswordCredentials, this is why we call raw api
$existingPasswordCredentialList = [IMicrosoftGraphPasswordCredential[]](Invoke-GraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$($currentState.Id)/passwordCredentials").Value;

# remove all existing passwords
foreach ($passwordCredential in $existingPasswordCredentialList) {
	Write-Host "App Registration Remove Secret [$($passwordCredential.DisplayName)]";

	Remove-MgApplicationPassword -ApplicationId $currentState.Id -KeyId $passwordCredential.KeyId;
}

# add new secrets
$secrets = @{};

foreach ($passwordCredential in $desiredState.PasswordCredentials) {
	Write-Host "App Registration Add Secret [$($passwordCredential.DisplayName)]";

	#add password
	$newPasswordCredential = Add-MgApplicationPassword -ApplicationId $currentState.Id -PasswordCredential $passwordCredential;

	$secrets[$newPasswordCredential.DisplayName] = $newPasswordCredential.SecretText;
};

<# return result #>

return @{
	clientId       = $currentState.AppId
	identifierUris = $identifierUris
	objectId       = $currentState.Id
	secrets        = $secrets
};
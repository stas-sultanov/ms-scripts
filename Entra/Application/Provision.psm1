using namespace Microsoft.Graph.Beta.PowerShell.Models;

function CreateApplication
{
	param
	(
		[parameter(Mandatory = $true)] [IMicrosoftGraphApplication] $desiredState
	)
	process
	{
		# create construction object
		$body = [IMicrosoftGraphApplication] @{
			Api                     = $desiredState.Api
			AppRoles                = $desiredState.AppRoles
			AuthenticationBehaviors = $desiredState.AuthenticationBehaviors
			DisplayName             = $desiredState.DisplayName
			Info                    = $desiredState.Info
			Notes                   = $desiredState.Notes
			OptionalClaims          = $desiredState.OptionalClaims
			RequiredResourceAccess  = $desiredState.RequiredResourceAccess
			SignInAudience          = $desiredState.SignInAudience
			Web                     = $desiredState.Web
		};

		# create new app registration
		$result = New-MgBetaApplication -BodyParameter $body;

		return $result;
	}
}

function UpdateApplication
{
	param
	(
		[parameter(Mandatory = $true)] [IMicrosoftGraphApplication] $application,
		[parameter(Mandatory = $true)] [IMicrosoftGraphApplication] $desiredState
	)
	process
	{
		$body = [IMicrosoftGraphApplication] @{
			Api                     = $desiredState.Api
			AppRoles                = $desiredState.AppRoles
			AuthenticationBehaviors = $desiredState.AuthenticationBehaviors
			Info                    = $desiredState.Info
			Notes                   = $desiredState.Notes
			OptionalClaims          = $desiredState.OptionalClaims
			RequiredResourceAccess  = $desiredState.RequiredResourceAccess
			SignInAudience          = $desiredState.SignInAudience
			Web                     = $desiredState.Web
		};

		Update-MgBetaApplication -ApplicationId $application.Id -BodyParameter $body;
	}
}

function Entra.Application.Provision
{
	<#
	.SYNOPSIS
		Provision an Application Registration within the Entra ID tenant.
	.DESCRIPTION
		Script assumes that names of the applications are unique within the Entra ID tenant.
		Uses Microsoft.Graph.Beta Powershell module.
	.PARAMETER accessToken
		Bearer token to access MS Graph.
	.PARAMETER callerIdentityObjectId
		ObjectId of the Identity which calls this script. Required to keep as owner.
	.PARAMETER logoFileName
		Name of the Logo file, including path.
	.PARAMETER manifestAsJson
		Name of the Main Manifest file, including path.
	.PARAMETER updatePasswordCredentials
		A Boolean value that indicates whether password credentials should be updated. Default true.
	.OUTPUTS
		System.Object
		On object with following fields:
			[System.Guid]     clientId
			[System.String[]] identifierUris
			[System.Guid]     objectId
			[System.Object[]] passwordCredentials
	.NOTES
		Copyright © 2024 Stas Sultanov.
	#>

	param
	(
		[parameter(Mandatory = $true)]  [SecureString] $accessToken,
		[parameter(Mandatory = $true)]  [String]       $callerIdentityObjectId,
		[parameter(Mandatory = $true)]  [String]       $logoFileName,
		[parameter(Mandatory = $true)]  [String]       $manifestAsJson,
		[parameter(Mandatory = $false)] [Boolean]      $updatePasswordCredentials = $true
	)
	process
	{
		# connect to Graph
		Connect-MgGraph -AccessToken $accessToken -NoWelcome;

		# get Graph Endpoint
		$graphEndpoint = ( Get-MgEnvironment -Name ( Get-MgContext ).Environment ).GraphEndpoint;

		<# read manifest file #>

		# load main manifest content as hashtable
		$manifestContent = $manifestAsJson | ConvertFrom-Json -AsHashtable;

		# deserialize
		$desiredState = [MicrosoftGraphApplication]::DeserializeFromDictionary( $manifestContent );

		<# get or create application #>

		# get all Applications Registrations with DisplayName eq specified
		$application = Get-MgBetaApplication -Filter "DisplayName eq '$($desiredState.DisplayName)'";

		# check if there is more then one app registration
		if ($application -is [array])
		{
			throw "Directory query returned more than one App Registration with DisplayName eq [$($desiredState.DisplayName)].";
		}

		# check if app not exist
		if ($null -eq $application)
		{
			Write-Host 'App Registration Create';

			$application = CreateApplication $desiredState;
		}
		else
		{
			Write-Host 'App Registration Update';

			UpdateApplication $application $desiredState;
		}

		# update identifier uris
		$identifierUris = [array] ($desiredState.IdentifierUris | ForEach-Object { $_.Replace('{Id}', $application.Id) });

		Update-MgBetaApplication -ApplicationId $application.Id -IdentifierUris $identifierUris;

		<# provision PublisherDomain #>

		if (![string]::IsNullOrEmpty($desiredState.PublisherDomain))
		{
			Write-Host 'App Registration Update PublisherDomain';

			Update-MgBetaApplication -ApplicationId $application.Id -PublisherDomain $desiredState.PublisherDomain;
		}

		<# provision Logo #>

		# check if logo file name was specified
		if (![string]::IsNullOrEmpty($logoFileName))
		{
			Write-Host 'App Registration Update Logo';

			Set-MgBetaApplicationLogo -ApplicationId $application.Id -InFile $logoFileName -ContentType 'image/*';
		}

		<# provision Owners #>

		# get owners from manifest
		$ownerIdList = @();

		if ($null -ne $desiredState.Owners)
		{
			$ownerIdList = $desiredState.Owners | Select-Object -ExpandProperty Id;
		}

		# get existing owners
		$existingOwnerIdList = Get-MgBetaApplicationOwner -ApplicationId $application.Id | Select-Object -ExpandProperty Id;

		# get owners to add, by excluding existing owners from specified in manifest
		$toAddOwnerIdList = $ownerIdList | Where-Object { $_ -notin $existingOwnerIdList };

		foreach ($ownerId in $toAddOwnerIdList)
		{
			Write-Host "App Registration Add Owner [$ownerId]";

			# add owner
			New-MgBetaApplicationOwnerByRef -ApplicationId $application.Id -OdataId "$graphEndpoint/v1.0/directoryObjects/$ownerId";
		}

		# get owners to remove, excluding current identity
		$toRemoveOwnerIdList = $existingOwnerIdList | Where-Object { ($_ -ne $callerIdentityObjectId) -and ($_ -notin $ownerIdList) };

		foreach ($ownerId in $toRemoveOwnerIdList)
		{
			Write-Host "App Registration Remove Owner [$ownerId]";

			# remove owner
			Remove-MgBetaApplicationOwnerByRef -ApplicationId $application.Id -DirectoryObjectId $ownerId;
		}

		<# provision PasswordCredentials #>
		$passwordCredentials = @{};

		if ($updatePasswordCredentials -eq $true)
		{

			# there is a no Get-MgApplicationPasswordCredentials, this is why we call raw api
			$existingPasswordCredentialList = [IMicrosoftGraphPasswordCredential[]](Invoke-GraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications/$($application.Id)/passwordCredentials").Value;

			# remove all existing passwords
			foreach ($passwordCredential in $existingPasswordCredentialList)
			{
				Write-Host "App Registration Remove Password [$($passwordCredential.DisplayName)]";

				Remove-MgBetaApplicationPassword -ApplicationId $application.Id -KeyId $passwordCredential.KeyId;
			};

			foreach ($passwordCredential in $desiredState.PasswordCredentials)
			{
				Write-Host "App Registration Add Password [$($passwordCredential.DisplayName)]";

				#add password
				$newPasswordCredential = Add-MgBetaApplicationPassword -ApplicationId $application.Id -PasswordCredential $passwordCredential;

				$passwordCredentials[$newPasswordCredential.DisplayName] = $newPasswordCredential.SecretText;
			};
		}

		<# provision VerifiedPublisher #>

		if (($null -ne $desiredState.VerifiedPublisher) -and ![string]::IsNullOrEmpty($desiredState.VerifiedPublisher.VerifiedPublisherId))
		{
			Write-Host 'App Registration Update VerifiedPublisher';

			Update-MgBetaApplication -ApplicationId $application.Id -VerifiedPublisher $desiredState.VerifiedPublisher;
		}

		<# return result #>

		return @{
			clientId            = $application.AppId
			identifierUris      = $identifierUris
			objectId            = $application.Id
			passwordCredentials = $passwordCredentials
		};
	}
}

Export-ModuleMember -Function Entra.Application.Provision;

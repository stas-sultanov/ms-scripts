<#
	author:		Stas Sultanov
	contact:	stas.sultanov@outlook.com
	gitHub:		https://github.com/stas-sultanov
	profile:	https://www.linkedin.com/in/stas-sultanov
.SYNOPSIS
	Dispose an Application Registration within the Entra ID tenant.
.NOTES
	Connect-AzAccount must be called before executing this script.
	Uses Mg library v1, also for Graph direct API calls.
.PARAMETER objectId
	Directory ObjectId of the Application Registration.
#>

param
(
	[parameter(Mandatory = $true)] [String] $objectId
)

<# implementation #>

# get access token
$accessToken = (Get-AzAccessToken -ResourceTypeName MSGraph).Token;

# secure access token
$accessTokenSecured = $accessToken | ConvertTo-SecureString -AsPlainText -Force;

# connect to Graph
Connect-MgGraph -AccessToken $accessTokenSecured -NoWelcome;

# check if application exists
$app = Get-MgApplication -Filter "Id eq '$objectId'";

# check if there is more then one application
if ($app -is [array])
{
	throw "Directory query returned several App Registrations with ObjectId [$objectId]."
}

Write-Output "App Registration Delete";

# remove application
Remove-MgApplication -ApplicationId $objectId;
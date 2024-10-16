@{
	# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
	AliasesToExport        = @()

	# Author of this module
	Author                 = 'Stas Sultanov'

	# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	# CLRVersion = ''

	# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
	CmdletsToExport        = @()

	# Company or vendor of this module
	CompanyName            = 'Stas Sultanov'

	# Supported PSEditions
	# CompatiblePSEditions = @()

	# Copyright statement for this module
	Copyright              = '© 2024 Stas Sultanov. All rights reserved'

	# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
	DefaultCommandPrefix = 'PowerPlatform.'

	# Description of the functionality provided by this module
	Description            = 'PowerShell interface for Microsoft Power Platform.'

	# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
	DotNetFrameworkVersion = '4.0.0.0'

	# DSC resources to export from this module
	DscResourcesToExport   = @()

	# List of all files packaged with this module
	# When included they are automatically loaded which can pull the files by name from uncontrolled locations.
	FileList               = @('PowerPlatform.psm1', 'PowerPlatform.psd1')

	# Format files (.ps1xml) to be loaded when importing this module
	# FormatsToProcess = @()

	# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
	FunctionsToExport      = @(
		'Environment.Create',
		'Environment.Delete',
		'Environment.Retrieve',
		'Environment.RetrieveAll',
		'Environment.Update',
		'ManagedIdentity.CreateIfNotExist',
		'ManagedIdentity.DeleteIfExist', 
		'SystemUser.CreateIfNotExist',
		'SystemUser.DeleteIfExist'
	)

	# ID used to uniquely identify this module
	GUID                   = 'd65c542d-5b6b-4c2f-b399-7997c585c673'

	# HelpInfo URI of this module
	# HelpInfoURI = ''

	# List of all modules packaged with this module
	ModuleList             = @('PowerPlatform')

	# Version number of this module.
	ModuleVersion          = '1.0.1'

	# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
	# NestedModules = @()

	# Name of the Windows PowerShell host required by this module
	# PowerShellHostName = ''

	# Minimum version of the Windows PowerShell host required by this module
	PowerShellHostVersion  = '1.0'

	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion      = '7.0'

	# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData            = @{
		PSData = @{
			# A URL to an icon representing this module.
			IconUri      = 'https://connectoricons-prod.azureedge.net/powerplatformforadmins/icon_1.0.1056.1255.png'
	
			# A URL to the license for this module.
			LicenseUri   = 'https://github.com/stas-sultanov/ms-scripts/blob/main/license'
	
			# A URL to the main website for this project.
			ProjectUri   = 'https://github.com/stas-sultanov/ms-scripts/tree/main/PowerPlatform'
	
			# ReleaseNotes of this module
			ReleaseNotes = 'nothing yet'
	
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags         = @()
		}
	}

	# Processor architecture (None, X86, Amd64) required by this module
	# ProcessorArchitecture = ''

	# Modules that must be imported into the global environment prior to importing this module
	#RequiredModules = @(@{ModuleName = ""; ModuleVersion = "1.0"; Guid = ""})

	# Script module or binary module file associated with this manifest.
	RootModule             = 'PowerPlatform.psm1'

	# Script files (.ps1) that are run in the caller's environment prior to importing this module.
	# ScriptsToProcess = @()

	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @()

	# Variables to export from this module
	# VariablesToExport = '*'
}

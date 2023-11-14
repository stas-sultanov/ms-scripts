Authored by Stas Sultanov [ [linkedIn](https://www.linkedin.com/in/stas-sultanov) | [gitHub](https://github.com/stas-sultanov) | [mail](mailto:stas.sultanov@outlook.com) ]

# About
Collection of Powershell scripts for Microsoft products and services.

# Content

```bash
Root
│
├── Azure                                       # Scripts for Microsoft Azure services.
│   │
│   ├── ApplicationInsights
│   │   └── ReCreateApiKey.ps1                  # Create or Reset ApiKey with name specified.
│   │
│   ├── CDN
│   │   └── EnableHTTPS.ps1                     # Enable HTTPS for all CDN profiles.
│   │
│   ├── DataFactory
│   │   └── ManageTriggerState.ps1              # Stop all triggers in specified Azure DataFactory instance.
│   │
│   ├── DevOpsPipelines
│   │   └── LoadAsVariables.ps1                 # Load file in JSON format as Azure DevOps Pipeline variables.
│   │
│   └── SqlServerDatabase
│       ├── CreateUserForEntraIdentity.ps1      # Create SQL Server Database User for Identity within the Entra ID tenant.
│       └── ManageUserAccess.ps1                # Set User access mode for the specified Sql Server Database.
│
├── Entra                                       # Scripts for Microsoft Entra services.
│   │
│   ├── Application
│   │   ├── Provision.ps1                       # Provision an Application Registration within the Entra ID tenant.
│   │   └── Remove.ps1                          # Remove an Application Registration within the Entra ID tenant.
│   │
│   ├── Group
│   │   └── Provision.ps1                       # Provision a Group within the Entra ID tenant.
│   │   └── Remove.ps1                          # Remove a Group within the Entra ID tenant.
│   │
│   └── Identity
│       └── AssignRole.ps1                      # Assign Identity to the specified Role within the Entra ID tenant.
│
├── license                                     # License file.
└── readme.md                                   # This file.
```

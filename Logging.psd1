@{RootModule = 'Logging.psm1'
ModuleVersion = '2.1'
GUID = 'fa078783-129e-4004-b181-2d45574213b4'
Author = 'Craig Plath'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '© Craig Plath. All rights reserved.'
Description = 'PowerShell module to enhance logging with log file clean-up, retention limit enforcement, error tracking and log viewing.'
PowerShellVersion = '5.1'
FunctionsToExport = @('cleanlogfiles', 'lasterrors', 'log', 'logviewer')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
FileList = @('Logging.psm1')

PrivateData = @{PSData = @{Tags = @('transcript', 'logging', 'viewer', 'development', 'errors', 'powershell')
LicenseUri = 'https://github.com/Schvenn/Assets/Logging/blob/main/LICENSE'
ProjectUri = 'https://github.com/Schvenn/Assets/Logging'
ReleaseNotes = 'Improved display and navigation.'}}}

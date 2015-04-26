<#############################################################################
The SmaPx module provides a rich set of commands that extend the automation
capabilities of Microsoft System Center Service Management Automation (SMA).
These commands offer additional value that is not natively available out of
the box to allow you to do much more with your PowerShell automation efforts
using the platform.

Copyright 2015 Provance Technologies.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#############################################################################>

@{
      ModuleToProcess = 'SmaPx.psm1'

        ModuleVersion = '0.9.0.0'

                 GUID = '2ea28a54-43c3-4b74-8ac4-133063dd1ed5'

               Author = 'Kirk Munro'

          CompanyName = 'Provance Technologies'

            Copyright = 'Copyright 2015 Provance Technologies'

          Description = 'The SmaPx module provides a rich set of commands that extend the automation capabilities of Microsoft System Center Service Management Automation (SMA). These commands offer additional value that is not natively available out of the box to allow you to do much more with your PowerShell automation efforts using the platform.'

    PowerShellVersion = '3.0'

        NestedModules = @(
                        'SnippetPx'
                        )

      RequiredModules = @(
                        'Microsoft.SystemCenter.ServiceManagementAutomation'
                        )

     ScriptsToProcess = @(
                        'scripts\Initialize-SmaPxOfflineCommandLibrary.ps1'
                        )

    FunctionsToExport = @(
                        'Edit-SmaPxRunbook'
                        'Get-SmaPxConnectionInfo'
                        'Get-SmaPxModule'
                        'Get-SmaPxRunbook'
                        'Get-SmaPxRunbookParameter'
                        'Get-SmaPxRunbookVersion'
                        'Invoke-SmaPxRunbook'
                        'New-SmaPxRunbook'
                        'Receive-SmaPxJob'
                        'Remove-SmaPxRunbook'
                        'Reset-SmaPxConnectionInfo'
                        'Set-SmaPxConnectionInfo'
                        'Set-SmaPxRunbook'
                        'Show-SmaPxDashboard'
                        'Show-SmaPxRunbook'
                        'Start-SmaPxRunbook'
                        'Test-SmaPxRunbook'
                        'Test-SmaPxRunbookWorker'
                        'Wait-SmaPxJob'
                        )

      AliasesToExport = @(
                        'SmaEdit'
                        )

             FileList = @(
                        'LICENSE'
                        'NOTICE'
                        'SmaPx.psd1'
                        'SmaPx.psm1'
                        'functions\Edit-SmaPxRunbook.ps1'
                        'functions\Get-SmaPxConnectionInfo.ps1'
                        'functions\Get-SmaPxModule.ps1'
                        'functions\Get-SmaPxRunbook.ps1'
                        'functions\Get-SmaPxRunbookParameter.ps1'
                        'functions\Get-SmaPxRunbookVersion.ps1'
                        'functions\Invoke-SmaPxRunbook.ps1'
                        'functions\New-SmaPxRunbook.ps1'
                        'functions\Receive-SmaPxJob.ps1'
                        'functions\Remove-SmaPxRunbook.ps1'
                        'functions\Reset-SmaPxConnectionInfo.ps1'
                        'functions\Set-SmaPxConnectionInfo.ps1'
                        'functions\Set-SmaPxRunbook.ps1'
                        'functions\Show-SmaPxDashboard.ps1'
                        'functions\Show-SmaPxRunbook.ps1'
                        'functions\Start-SmaPxRunbook.ps1'
                        'functions\Test-SmaPxRunbook.ps1'
                        'functions\Test-SmaPxRunbookWorker.ps1'
                        'functions\Wait-SmaPxJob.ps1'
                        'helpers\Invoke-SmaPxWebRequest.ps1'
                        'helpers\Update-SmaPxDefaultConnectionParameterSet.ps1'
                        'scripts\Initialize-SmaPxOfflineCommandLibrary.ps1'
                        )

          PrivateData = @{
                            PSData = @{
                                Tags = 'system center service management automation sma'
                                LicenseUri = 'http://apache.org/licenses/LICENSE-2.0.txt'
                                ProjectUri = 'http://github.com/KirkMunro/SmaPx'
                                IconUri = ''
                                ReleaseNotes = ''
                            }
                        }
}
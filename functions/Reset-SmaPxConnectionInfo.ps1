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

function Reset-SmaPxConnectionInfo {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Void])]
    param()
    try {
        #region If this is being invoked from a SMA runbook worker, raise an error.

        if (($process = Get-Process -Id $PID).Name -eq 'Orchestrator.Sandbox') {
            [System.String]$message = 'You cannot invoke this command from a SMA runbook because connection details are not cached the same way that they are in scripts. Use the Set-SmaConnectionFieldValue cmdlet instead.'
            [System.InvalidOperationException]$exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'InvalidOperationException',([System.Management.Automation.ErrorCategory]::InvalidOperation),$process
            throw $errorRecord
        }

        #endregion

        if ($PSCmdlet.ShouldProcess('SmaPx connection info','Reset')) {
            #region Update the connection info object in memory.

            $script:ModuleConfig.WebServiceEndpoint = $null
            $script:ModuleConfig.Port = $null
            $script:ModuleConfig.AuthenticationType = $null
            $script:ModuleConfig.Credential = $null

            #endregion

            #region Remove the default connection info from the SMA cmdlets and SmaPx commands.

            Update-SmaPxDefaultConnectionParameterSet

            #endregion

            #region Remove the connection info that is stored on disk.

            if (Test-Path -LiteralPath $script:ModuleConfigFolder) {
                Remove-Item -LiteralPath $script:ModuleConfigFolder -Recurse -Force
            }

            #endregion
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Reset-SmaPxConnectionInfo
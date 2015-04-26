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

function Set-SmaPxConnectionInfo {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Void])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not ($_ -match '^https?://') -or ($_ -match '[#\?]')) {
                throw 'Expected an absolute, well formed http URL without a query or fragment.'
            }
            $true
        })]
        [System.String]
        $WebServiceEndpoint,

        [Parameter(Position=1)]
        [ValidateNotNull()]
        [ValidateRange(1,65535)]
        [System.Int32]
        $Port = 9090,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    try {
        #region If this is being invoked from a SMA runbook worker, raise an error.

        if (($process = Get-Process -Id $PID).Name -eq 'Orchestrator.Sandbox') {
            [System.String]$message = 'You cannot invoke this command from a SMA runbook because connection details are not cached the same way that they are in scripts. Use the Set-SmaConnectionFieldValue cmdlet instead.'
            [System.InvalidOperationException]$exception = New-Object -TypeName System.InvalidOperationException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'InvalidOperationException',([System.Management.Automation.ErrorCategory]::InvalidOperation),$process
            throw $errorRecord
        }

        #endregion

        #region Set a flag to track whether or not changes are made.

        $updated = $false

        #endregion

        #region Update the connection info object in memory.

        if ($PSCmdlet.ShouldProcess('SmaPx connection info','Set web service endpoint')) {
            $updated = $true
            $script:ModuleConfig.WebServiceEndpoint = $WebServiceEndpoint
        }

        if ($PSCmdlet.ShouldProcess('SmaPx connection info','Set port')) {
            $updated = $true
            if ($Port -eq 9090) {
                # Use the default port, don't bother passing it through
                $script:ModuleConfig.Port = $null
            } else {
                # Use a non-default port
                $script:ModuleConfig.Port = $Port
            }
        }

        if ($PSCmdlet.ShouldProcess('SmaPx connection info','Set credential')) {
            $updated = $true
            if ($Credential -eq [System.Management.Automation.PSCredential]::Empty) {
                # Use Windows authentication, no credentials required
                $script:ModuleConfig.AuthenticationType = $null
                $script:ModuleConfig.Credential = $null
            } else {
                # Use Basic authentication
                $script:ModuleConfig.AuthenticationType = 'Basic'
                $script:ModuleConfig.Credential = $Credential
            }
        }

        #endregion

        if ($updated) {
            #region Apply the connection info to the SMA cmdlets.

            Update-SmaPxDefaultConnectionParameterSet

            #endregion

            #region Write the connection info to disk.

            if (-not (Test-Path -LiteralPath $script:ModuleConfigFolder)) {
                New-Item -Path $script:ModuleConfigFolder -ItemType Directory > $null
            }
            Export-Clixml -InputObject $script:ModuleConfig -LiteralPath $script:ModuleConfigFile

            #endregion
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Set-SmaPxConnectionInfo
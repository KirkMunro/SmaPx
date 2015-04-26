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

function Sync-SmaPxSandbox {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Void])]
    param(
        [Parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $RunbookName = '*',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not ($_ -match '^https?://') -or ($_ -match '[#\?]')) {
                throw 'Expected an absolute, well formed http URL without a query or fragment.'
            }
            $true
        })]
        [System.String]
        $WebServiceEndpoint,

        [Parameter()]
        [ValidateNotNull()]
        [ValidateRange(1,65535)]
        [System.Int32]
        $Port = 9090,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Basic','Windows')]
        [System.String]
        $AuthenticationType = 'Windows'
    )
    try {
        #region Identify the passthru connection parameters.

        $connectionParameters = @{}
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Credential') -and ($Credential -eq [System.Management.Automation.PSCredential]::Empty)) {
            $PSCmdlet.MyInvocation.BoundParameters.Remove('Credential') > $null
        }
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Port') -and ($Port -eq 9090)) {
            $PSCmdlet.MyInvocation.BoundParameters.Remove('Port') > $null
        }
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('AuthenticationType') -and ($AuthenticationType -eq 'Windows')) {
            $PSCmdlet.MyInvocation.BoundParameters.Remove('AuthenticationType') > $null
        }
        foreach ($parameterName in $script:smaConnectionParameterNames) {
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                $connectionParameters[$parameterName] = $PSCmdlet.MyInvocation.BoundParameters[$parameterName]
            }
        }

        #endregion

        #region Get the runbooks that we want to edit.

        $runbooks = @(Get-SmaPxRunbook @PSBoundParameters)

        #endregion

        #region If no runbooks were found, raise an error.

        if (-not $runbooks) {
            [System.String]$message = 'No runbooks were found that match the input parameters.'
            [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
            [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$PSBoundParameters
            throw $errorRecord
        }

        #endregion

        #region Push the current version of each of the runbooks as the latest draft into SMA.

        foreach ($runbook in $runbooks) {
            #region Read the runbook definition according to its current draft state and whether or not it should be overwritten.

            Write-Verbose -Message "Reading runbook definition for '$($runbook.RunbookName)'."
            if ($runbook.DraftRunbookVersionID -and -not $overwriteParameter.Count) {
                $sourceType = 'Draft'
            } else {
                $sourceType = 'Published'
            }
            $runbookDefinition = Get-SmaRunbookDefinition -Id $runbook.RunbookID -Type $sourceType @connectionParameters

            #endregion

            #region Create the sandbox folder if it does not exist.

            if (-not (Test-Path -LiteralPath $script:SmaSandboxPath)) {
                Write-Verbose -Message "Creating SMA Sandbox folder at '${script:SmaSandboxPath}'."
                New-Item -Path $script:SmaSandboxPath -ItemType Directory > $null
            }

            #endregion

            #region Copy the runbook script from SMA to the sandbox, if appropriate.

            # We don't copy the runbook script if we already have it and if we are not overwriting it.
            $runbookSandboxPath = Join-Path -Path $script:SmaSandboxPath -ChildPath "$($runbook.RunbookName).ps1"
            if ((-not (Test-Path -LiteralPath $runbookSandboxPath)) -or (-not $runbook.DraftRunbookVersionID) -or $overwriteParameter.Count) {
                Write-Verbose -Message "Writing runbook to '${runbookSandboxPath}'."
                [System.IO.File]::WriteAllText($runbookSandboxPath, $runbookDefinition.Content, [System.Text.Encoding]::UTF8)
            }

            #endregion

            #region Create a new draft of the runbook on the SMA server, if appropriate.

            # This would be better placed in the top of this foreach loop, however since the Edit-SmaRunbook
            # command requires a local file (bad design idea), we need to do this at the end of the foreach
            # loop.

            if ($sourceType -eq 'Published') {
                Write-Verbose -Message "Creating new draft of runbook '$($runbook.RunbookName)' on SMA Server."
                Edit-SmaRunbook -Id $runbook.RunbookID -Path $runbookSandboxPath @overwriteParameter @connectionParameters
            }

            #endregion

            #region Open the runbook in the default editor.

            Write-Verbose -Message "Opening '${runbookSandboxPath}' in the default editor."
            Start-Process -FilePath $runbookSandboxPath -Verb Edit

            #endregion
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Sync-SmaPxRunbook
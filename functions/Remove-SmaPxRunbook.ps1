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

function Remove-SmaPxRunbook {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='ByName')]
    [OutputType([System.Void])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookName')]
        [System.String[]]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookId')]
        [System.Guid[]]
        $Id,

        [Parameter(Mandatory=$true, ParameterSetName='ByTag')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Tag,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $DraftOnly,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $CleanSandbox,

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
    begin {
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

            #region Remove DraftOnly from the bound parameters.

            $DraftOnly = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('DraftOnly') -and $DraftOnly
            $PSCmdlet.MyInvocation.BoundParameters.Remove('DraftOnly') > $null

            #endregion

            #region Remove CleanSandbox from the bound parameters.

            $CleanSandbox = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('CleanSandbox') -and $CleanSandbox
            $PSCmdlet.MyInvocation.BoundParameters.Remove('CleanSandbox') > $null

            #endregion

            #region Remove WhatIf and Confirm from the bound parameters.

            foreach ($parameterName in 'WhatIf','Confirm') {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                    $PSCmdlet.MyInvocation.BoundParameters.Remove($parameterName) > $null
                }
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            if ($_.PSTypeNames -contains 'Orchestrator.WebService.Client.OaaSClient.Runbook') {
                #region If a runbook was used as the pipeline input, then don't get the runbook again.

                $runbooks = @($_)

                #endregion
            } else {
                #region Get the runbooks that we want to remove all or part of.

                $runbooks = @(Get-SmaPxRunbook @PSBoundParameters)

                #endregion
            }

            #region Remove either the entire runbook or the draft version of the runbook, according to the parameters used.

            foreach ($runbook in $runbooks) {
                #region Identify the relative Uri based on the type of delete we are doing.

                if ($DraftOnly -and $runbook.DraftRunbookVersionID -and $runbook.PublishedRunbookVersionID) {
                    Write-Verbose -Message "Removing current draft version of runbook '$($runbook.RunbookName)'."
                    # Identify the URI for the draft version of the runbook
                    $relativeUri = "RunbookVersions(guid'$($runbook.DraftRunbookVersionID)')"
                } else {
                    Write-Verbose -Message "Removing runbook '$($runbook.RunbookName)'."
                    # Identify the URI for the runbook
                    $relativeUri = "Runbooks(guid'$($runbook.RunbookID)')"
                }

                #endregion

                #region Now invoke the Delete request.

                try {
                    Invoke-SmaPxWebRequest -RelativeUri $relativeUri -Method Delete
                } catch [System.Net.WebException] {
                    if ($_.Exception.Response -and
                        ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound)) {
                        # Swallow this specific error, since it indicates there is no draft runbook with the GUID that was provided so nothing to do
                    } else {
                        throw $_
                    }
                }

                #endregion

                #region Finally, remove the runbook from disk in interactive sessions if it is in the local sandbox and you wanted it removed.

                if ([System.Environment]::UserInteractive) {
                    $runbookSandboxPath = Join-Path -Path $script:SmaSandboxPath -ChildPath "$($runbook.RunbookName).ps1"
                    if ($CleanSandbox -and (Test-Path -LiteralPath $runbookSandboxPath)) {
                        Write-Verbose -Message "Removing local sandbox copy of runbook ('${runbookSandboxPath}')."
                        Remove-Item -LiteralPath $runbookSandboxPath -Force
                    }
                }

                #endregion
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Remove-SmaPxRunbook
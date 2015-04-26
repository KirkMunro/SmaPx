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

function Edit-SmaPxRunbook {
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
        $Overwrite,

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

            #region Remove the Overwrite parameter if it was set.
        
            if ($Overwrite = ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Overwrite') -and $Overwrite)) {
                $PSCmdlet.MyInvocation.BoundParameters.Remove('Overwrite') > $null
            }

            #endregion

            #region Remove WhatIf and Confirm from the bound parameters.

            foreach ($parameterName in 'WhatIf','Confirm') {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                    $PSCmdlet.MyInvocation.BoundParameters.Remove($parameterName) > $null
                }
            }

            #endregion

            #region Define a collection to store all runbooks we are going to edit.

            $runbooks = @{}

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            if ($_.PSTypeNames -contains 'Orchestrator.WebService.Client.OaaSClient.Runbook') {
                #region Add the new runbooks that were passed in from the pipeline.

                if (-not $runbooks.ContainsKey($_.RunbookName)) {
                    $runbooks[$_.RunbookName] = $_
                }

                #endregion
            } else {
                #region Get the new runbooks that we want to edit.

                foreach ($runbook in Get-SmaPxRunbook @PSBoundParameters) {
                    if (-not $runbooks.ContainsKey($runbook.RunbookName)) {
                        $runbooks[$runbook.RunbookName] = $runbook
                    }
                }

                #endregion
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end {
        try {
            #region If no runbooks were found, raise an error.

            if ($runbooks.Count -eq 0) {
                [System.String]$message = 'No runbooks were found that match the input parameters.'
                [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$PSBoundParameters
                throw $errorRecord
            }

            #endregion

            #region Open each of the matching runbooks as draft in the default editor.

            foreach ($runbookName in $runbooks.Keys | Sort-Object) {
                #region Create a reference to the runbook object.

                $runbook = $runbooks[$runbookName]

                #endregion

                #region If the runbook is published, has a draft version, and if -Overwrite was used, remove the draft version.

                if ($runbook.PublishedRunbookVersionID -and $runbook.DraftRunbookVersionID -and $Overwrite) {
                    $runbook | Remove-SmaPxRunbook -DraftOnly @connectionParameters -CleanSandbox
                }

                #endregion

                #region If the runbook is published and does not have a draft version or if -Overwrite was used, create a draft version.

                if ($runbook.PublishedRunbookVersionID -and
                    ((-not $runbook.DraftRunbookVersionID) -or $Overwrite)) {
                    Write-Verbose -Message "Creating draft version of runbook '$($runbook.RunbookName)'."
                    # Specify the relative uri for the runbook's edit method
                    $relativeUri = "Runbooks(guid'$($runbook.RunbookID)')/Edit"
                    # Invoke the edit method
                    Invoke-SmaPxWebRequest -RelativeUri $relativeUri -Method Post > $null
                }

                #endregion

                #region If this was invoked interactively, copy the file to the local sandbox and open it in the default editor.

                if ([System.Environment]::UserInteractive) {
                    #region Now that we have the draft version in the state that we want, read the draft runbook definition.

                    Write-Verbose -Message "Reading draft runbook definition for '$($runbook.RunbookName)'."
                    $relativeUri = "RunbookVersions(guid'$($runbook.DraftRunbookVersionID)')/`$value"
                    $webResults = Invoke-SmaPxWebRequest -RelativeUri $relativeUri -Method Get

                    #endregion

                    #region Create the sandbox folder if it does not exist.

                    if (-not (Test-Path -LiteralPath $script:SmaSandboxPath)) {
                        Write-Verbose -Message "Creating SMA Sandbox folder at '${script:SmaSandboxPath}'."
                        New-Item -Path $script:SmaSandboxPath -ItemType Directory > $null
                    }

                    #endregion

                    #region Copy the runbook script from SMA to the sandbox, if appropriate.

                    # Don't copy the runbook script if we already have it and if we are not overwriting it.
                    $runbookSandboxPath = Join-Path -Path $script:SmaSandboxPath -ChildPath "$($runbook.RunbookName).ps1"
                    if ((-not (Test-Path -LiteralPath $runbookSandboxPath)) -or (-not $runbook.DraftRunbookVersionID) -or $Overwrite) {
                        Write-Verbose -Message "Writing draft version of runbook to local file at '${runbookSandboxPath}'."
                        [System.IO.File]::WriteAllText($runbookSandboxPath, $webResults.Resource, [System.Text.Encoding]::UTF8)
                        # Read the current list of tags
                        $tags = @{}
                        if (Test-Path -LiteralPath $SmaSandboxTags) {
                            $tags = Import-Clixml -LiteralPath $SmaSandboxTags
                        }
                        # Remove any tags for which we no longer have files (files that were manually deleted)
                        $sandboxRunbooks = @(
                            Get-ChildItem -LiteralPath $script:SmaSandboxPath -Filter *.ps1 `
                                | Where-Object {-not $_.PSIsContainer -and ($_.Extension -eq '.ps1')} `
                                | Select-Object -ExpandProperty BaseName
                        )
                        foreach ($tag in @($tags.Keys)) {
                            if ($sandboxRunbooks -notcontains $tag) {
                                $tags.Remove($tag)
                            }
                        }
                        # Write the eTag to a tags file so that we can use it again later
                        $tags[$runbook.RunbookName] = $webResults.ETag
                        Export-Clixml -LiteralPath $SmaSandboxTags
                    }

                    #endregion

                    #region Open the runbook in the default editor.

                    Write-Verbose -Message "Opening '${runbookSandboxPath}' in the default editor."
                    Start-Process -FilePath $runbookSandboxPath -Verb Edit

                    #endregion
                }

                #endregion
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Edit-SmaPxRunbook

if (-not (Get-Alias -Name SmaEdit -ErrorAction SilentlyContinue)) {
    New-Alias -Name SmaEdit -Value Edit-SmaPxRunbook -Description 'Open an SMA Runbook in the default PowerShell script editor.'
    Export-ModuleMember -Alias SmaEdit
}
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

function Get-SmaPxRunbook {
    [CmdletBinding(DefaultParameterSetName='ByName')]
    [OutputType('Orchestrator.WebService.Client.OaaSClient.Runbook')]
    param(
        [Parameter(Position=0, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookName')]
        [System.String[]]
        $Name = '*',

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookId')]
        [System.Guid[]]
        $Id,

        [Parameter(Mandatory=$true, ParameterSetName='ByTag')]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Tag,

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

        #region Identify the passthru lookup parameters.

        $lookupParameters = @{}
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Id')) {
            $lookupParameters['Id'] = $Id
        }

        #endregion

        #region Get the initial set of runbooks we want to start filtering on from SMA.

        $runbooks = Get-SmaRunbook @lookupParameters @connectionParameters | Sort-Object -Property RunbookName

        #endregion

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                if ($Name -match '^\*$') {
                    #region Return all runbooks.

                    $runbooks

                    #endregion
                } else {
                    #region Return runbooks that match one or more of the Name values, supporting wildcards and regardless of case.

                    $allRunbookMatches = @()
                    $resultSet = @()
                    foreach ($runbookName in $Name) {
                        $currentRunbookMatches = @()
                        foreach ($runbook in $runbooks) {
                            if (($allRunbookMatches -contains $runbook.RunbookName) -or
                                ($currentRunbookMatches -contains $runbook.RunbookName)) {
                                continue
                            }
                            if ($runbookName -match '[\*?]') {
                                if ($runbook.RunbookName -like $runbookName) {
                                    $currentRunbookMatches += $runbook.RunbookName
                                    $resultSet += $runbook
                                }
                            } elseif ($runbook.RunbookName -eq $runbookName) {
                                $currentRunbookMatches += $runbook.RunbookName
                                $resultSet += $runbook
                                break
                            }
                        }
                        if ($currentRunbookMatches) {
                            $allRunbookMatches += $currentRunbookMatches
                        } elseif ($runbookName -notmatch '[\*?]') {
                            $message = "The runbook ${runbookName} cannot be found."
                            $exception = New-Object -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookNotFoundException -ArgumentList $message
                            Write-Error -Exception $exception
                        }
                    }
                    $resultSet | Sort-Object -Property RunbookName

                    #endregion
                }
                break
            }
            'ById' {
                #region Return the runbooks we already retrieved.

                # No extra work is required when lookup up runbooks by id.
                $runbooks

                #endregion
                break
            }
            'ByTag' {
                #region Return runbooks that match one or more of the Tag values, supporting wildcards and regardless of case.

                $allRunbookMatches = @()
                $tagsProcessed = @()
                $resultSet = @()
                foreach ($runbookTag in $Tag) {
                    $currentRunbookMatches = @()
                    foreach ($runbook in $runbooks) {
                        $runbookTags = @($runbook.Tags -split ',')
                        if (($allRunbookMatches -contains $runbook.RunbookName) -or
                            ($currentRunbookMatches -contains $runbook.RunbookName)) {
                            continue
                        }
                        if ($runbookTag -match '[\*?]') {
                            if ($runbookTags -like $runbookTag) {
                                $currentRunbookMatches += $runbook.RunbookName
                                $tagsProcessed += $runbookTags
                                $resultSet += $runbook
                            }
                        } elseif ($runbookTags -eq $runbookTag) {
                            $currentRunbookMatches += $runbook.RunbookName
                            $tagsProcessed += $runbookTags
                            $resultSet += $runbook
                        }
                    }
                    if ($currentRunbookMatches) {
                        $allRunbookMatches += $currentRunbookMatches
                    } elseif (($runbookTag -notmatch '[\*?]') -and ($tagsProcessed -notcontains $runbookTag)) {
                        $message = "The runbook tag ${runbookTag} cannot be found."
                        $exception = New-Object -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookNotFoundException -ArgumentList $message
                        Write-Error -Exception $exception
                    }
                }
                $resultSet | Sort-Object -Property RunbookName

                #endregion
                break
            }
        }

    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-SmaPxRunbook
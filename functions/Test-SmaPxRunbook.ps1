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

function Test-SmaPxRunbook {
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
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $Parameters,

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
                #region Get the runbooks that we want to test.

                $runbooks = @(Get-SmaPxRunbook @PSBoundParameters)

                #endregion
            }

            #region Test each of the runbooks that have a draft version to test.

            foreach ($runbook in $runbooks) {
                #region If the runbook does not have a draft version, raise a warning and continue.

                if (-not $runbook.DraftRunbookVersionID) {
                    Write-Warning -Message "Runbook '$($runbook.RunbookName)' does not have a draft version and therefore will not be tested."
                    continue
                }

                #endregion

                #region Identify the relative Uri for the Test method.

                $relativeUri = "Runbooks(guid'$($runbook.RunbookID)')/Test"

                #endregion

                #region Unbox any values in the Parameters parameter if it is set.

                $unboxedParameters = @{}
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Parameters')) {
                    $unboxedParameters = $Parameters.Clone()
                    foreach ($runbookParameter in Get-SmaPxRunbookParameter -VersionId $runbook.DraftRunbookVersionID @connectionParameters) {
                        if (($unboxedParameters.ContainsKey($runbookParameter.Name)) -and
                            ($runbookParameterType = $runbookParameter.Type -as [System.Type])) {
                            $unboxedParameters[$runbookParameter.Name] = $unboxedParameters[$runbookParameter.Name] -as $runbookParameterType
                        }
                    }
                }

                #endregion

                #region Now start the Test by invoking a Post request.

                try {
                    Write-Verbose -Message "Testing runbook '$($runbook.RunbookName)'."
                    $jsonParameters = ConvertTo-Json -InputObject @{
                        parameters = $(if ($unboxedParameters.Count) {$unboxedParameters} else {$null})
                    }
                    if ($results = Invoke-SmaPxWebRequest -RelativeUri $relativeUri -Method Post -Body $jsonParameters) {
                        $jobId = $results.d.Test -as [System.Guid]
                        Wait-SmaPxJob -Id $jobId @connectionParameters | Receive-SmaPxJob @connectionParameters
                    }
                } catch [System.Net.WebException] {
                    if ($_.Exception.Response -and
                        ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound)) {
                        # Swallow this specific error, since it indicates there is no draft runbook with the GUID that was provided so nothing to do
                    } else {
                        throw
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

Export-ModuleMember -Function Test-SmaPxRunbook
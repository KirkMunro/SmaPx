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

function Start-SmaPxRunbook {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='ByName')]
    [OutputType('Microsoft.SystemCenter.ServiceManagementAutomation.Job')]
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
        [System.String]
        $ScheduleName,

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
        $AuthenticationType = 'Windows',

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru
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

            #region Identify the passthru schedulename parameter.

            $scheduleNameParameter = @{}
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ScheduleName')) {
                $scheduleNameParameter['ScheduleName'] = $ScheduleName
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
                #region Identify the passthru lookup parameters.

                $lookupParameters = @{}
                foreach ($parameterName in 'Name','Id','Tag') {
                    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                        $lookupParameters[$parameterName] = $PSCmdlet.MyInvocation.BoundParameters[$parameterName]
                    }
                }

                #endregion

                #region Get the runbooks that we want to start.

                $runbooks = @(Get-SmaPxRunbook @lookupParameters @connectionParameters)

                #endregion
            }

            #region Start the runbook according to the parameters that were used.

            foreach ($runbook in $runbooks) {
                #region If the runbook does not have a published version, raise a warning and continue.

                if (-not $runbook.PublishedRunbookVersionID) {
                    Write-Warning -Message "Runbook '$($runbook.RunbookName)' does not have a published version and therefore will not be started. Use Test-SmaPxRunbook to test the draft version, or Publish-SmaPxRunbook to publish the runbook and then try again."
                    continue
                }

                #endregion

                #region Identify the passthru parameters parameter.

                $parametersParameter = @{}
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Parameters')) {
                    $unboxedParameters = $Parameters.Clone()
                    foreach ($runbookParameter in Get-SmaPxRunbookParameter @lookupParameters -Type Published @connectionParameters) {
                        if (($unboxedParameters.ContainsKey($runbookParameter.Name)) -and
                            ($runbookParameterType = $runbookParameter.Type -as [System.Type])) {
                            $unboxedParameters[$runbookParameter.Name] = $unboxedParameters[$runbookParameter.Name] -as $runbookParameterType
                        }
                    }
                    $parametersParameter['Parameters'] = $unboxedParameters
                }

                #endregion

                #region Start the job.

                $jobId = Start-SmaRunbook -Id $runbook.RunbookID @parametersParameter @scheduleNameParameter @connectionParameters

                #endregion

                #region Return the Job object to the caller.

                Get-SmaJob -Id $jobId @connectionParameters

                #endregion
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Start-SmaPxRunbook
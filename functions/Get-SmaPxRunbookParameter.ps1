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

function Get-SmaPxRunbookParameter {
    [CmdletBinding(DefaultParameterSetName='ByName')]
    [OutputType('Orchestrator.ResourceModel.RunbookParameter')]
    param(
        [Parameter(Position=0, ValueFromPipelineByPropertyName=$true, ParameterSetName='ByName')]
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

        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='ByVersionId')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookVersionID')]
        [System.Guid[]]
        $VersionId,

        [Parameter(ParameterSetName='ByName')]
        [Parameter(ParameterSetName='ById')]
        [Parameter(ParameterSetName='ByTag')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Published','Draft')]
        [System.String]
        $Type = 'Published',

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
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'ByVersionId' {
                    #region Lookup the runbook parameters.

                    $relativeUri = "RunbookVersions(guid'${VersionId}')/RunbookParameters"
                    Invoke-SmaPxWebRequest -RelativeUri $relativeUri -Method Get | Sort-Object

                    #endregion
                    break
                }
                default {
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
                        
                        #region Get the runbooks that we want to get versions for.

                        $runbooks = @(Get-SmaPxRunbook @lookupParameters @connectionParameters)

                        #endregion

                        #region Look up the appropriate version for each of the runbooks.

                        foreach ($runbook in $runbooks) {
                            if (($Type -eq 'Published') -and $runbook.PublishedRunbookVersionID) {
                                Get-SmaPxRunbookParameter -VersionId $runbook.PublishedRunbookVersionID @connectionParameters
                            } elseif (($Type -eq 'Draft') -and $runbook.DraftRunbookVersionID) {
                                Get-SmaPxRunbookParameter -VersionId $runbook.DraftRunbookVersionID @connectionParameters
                            }
                        }

                        #endregion
                    }
                    break
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Get-SmaPxRunbookParameter
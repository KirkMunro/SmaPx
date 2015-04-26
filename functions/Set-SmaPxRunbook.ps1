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

function Set-SmaPxRunbook {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='ByName')]
    [OutputType('Orchestrator.WebService.Client.OaaSClient.Runbook')]
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

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String[]]
        $Tag,

        [Parameter()]
        [System.String[]]
        $AddTag,

        [Parameter()]
        [System.String[]]
        $RemoveTag,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $LogProgress,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $LogVerbose,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $LogDebug,

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

            #region Identify the properties that have static values that will be applied to the runbook(s).

            # We leave Tag processing until the process block, since it may have
            # dynamic values derived from the Tag, AddTag, and RemoveTag parameters.
            $propertyHashTable = @{}
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Description')) {
                $propertyHashTable['Description'] = $(if ($Description) {$Description} else {$null})
            }
            foreach ($switchParameterName in 'LogProgress','LogVerbose','LogDebug') {
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($switchParameterName)) {
                    $propertyHashTable[$switchParameterName] = [bool]$PSCmdlet.MyInvocation.BoundParameters.$switchParameterName
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
                #region Identify the lookup parameters.

                $lookupParameters = @{}
                foreach ($parameterName in 'Name','Id') {
                    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                        $lookupParameters[$parameterName] = $PSCmdlet.MyInvocation.BoundParameters.$parameterName
                    }
                }

                #endregion

                #region Get the runbooks that we want to set properties on.

                $runbooks = @(Get-SmaPxRunbook @lookupParameters @connectionParameters)

                #endregion
            }

            #region Set the properties of the runbook according to the parameters that were used.

            foreach ($runbook in $runbooks) {
                #region Identify the relative Uri using the runbook id.

                Write-Verbose -Message "Setting properties on runbook '$($runbook.RunbookName)'."
                # Identify the URI for the runbook
                $relativeUri = "Runbooks(guid'$($runbook.RunbookID)')"

                #endregion

                #region Make a copy of the property hash table for modification.

                $propertyHashTableCopy = $propertyHashTable.Clone()

                #endregion

                #region Set the runbook name and id in the property hash table.

                $propertyHashTableCopy['RunbookName'] = $runbook.RunbookName
                $propertyHashTableCopy['RunbookID'] = $runbook.RunbookID

                #endregion

                #region Update the Tags property according to the Tag, AddTag, and RemoveTag parameters.

                $tags = @($runbook.Tags -split ',')
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Tag')) {
                    $tags = $Tag
                }
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('AddTag')) {
                    $tags += $AddTag
                }
                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('RemoveTag')) {
                    $tags = @($tags | Where-Object {$RemoveTag -notcontains $_})
                }
                $propertyHashTableCopy['Tags'] = $(if ($tags) {$tags -join ','} else {$null})

                #endregion

                #region Remove any non-identifying properties that have not changed from their current values.

                foreach ($propertyName in @($propertyHashTableCopy.Keys)) {
                    # Leave the runbook name and id since those are required
                    if (@('RunbookName','RunbookID') -contains $propertyName) {
                        continue
                    }
                    # Remove other properties if they have not changed
                    if ($runbook.$propertyName -eq $propertyHashTableCopy.$propertyName) {
                        $propertyHashTableCopy.Remove($propertyName)
                    }
                }

                #endregion

                #region Invoke the Put request if changes are being made to runbook properties.

                if ($propertyHashTableCopy.Count -gt 2) {
                    try {
                        $jsonParameters = ConvertTo-Json -InputObject $propertyHashTableCopy
                        Invoke-SmaPxWebRequest -RelativeUri $relativeUri -Method Put -Body $jsonParameters
                    } catch [System.Net.WebException] {
                        if ($_.Exception.Response -and
                            ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound)) {
                            # Swallow this specific error, since it indicates there is no draft runbook with the GUID that was provided so nothing to do
                        } else {
                            throw $_
                        }
                    }
                }

                #endregion

                #region Return the updated runbook object if it was requested.

                if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('PassThru') -and $PassThru) {
                    foreach ($propertyName in $propertyHashTableCopy.Keys) {
                        $runbook.$propertyName = $propertyHashTableCopy.$propertyName
                    }
                    $runbook
                }

                #endregion
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Set-SmaPxRunbook
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

function New-SmaPxRunbook {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType('Orchestrator.WebService.Client.OaaSClient.Runbook')]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookName')]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ScriptBlock]
        $ScriptBlock,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Tag,

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

        #region Identify the passthru property parameters.

        $propertyParameters = @{}
        foreach ($parameterName in 'Description','Tag','LogProgress','LogVerbose','LogDebug') {
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                $propertyParameters[$parameterName] = $PSCmdlet.MyInvocation.BoundParameters.$parameterName
            }
        }

        #endregion

        #region Create the runbook by invoking a Post request on the Runbooks collection.

        Write-Verbose -Message "Creating runbook '${Name}'."
        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ScriptBlock')) {
            $body = @"
workflow ${Name} {
${ScriptBlock}
}
"@
        } else {
            $body = @"
workflow ${Name} {
}
"@
        }
        if ($results = Invoke-SmaPxWebRequest -RelativeUri RunbookVersions -Method Post -Body $body) {
            $draftRunbookVersionId = $results.d.RunbookVersionID -as [System.Guid]
            if ($runbook = Get-SmaPxRunbook -Name $Name @connectionParameters) {
                if ($propertyParameters.Count) {
                    $runbook | Set-SmaPxRunbook @propertyParameters @connectionParameters -PassThru
                } else {
                    $runbook
                }
            }
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function New-SmaPxRunbook
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

function Show-SmaPxRunbook {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='ByName')]
    [OutputType([System.Void])]
    param(
        [Parameter(Position=0, Mandatory=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookName')]
        [System.String[]]
        $Name,

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
        [ValidateSet('Dashboard','Jobs','Author','Schedule','Configure')]
        [System.String]
        $View = 'Author',

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
        #region Remove the View parameter from the bound parameter set.

        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('View')) {
            $PSCmdlet.MyInvocation.BoundParameters.Remove('View')
        }

        #endregion

        #region Get the runbooks that we want to show.

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

        #region If more than 10 runbooks were found, raise a warning.

        if ($runbooks.Count -gt 10) {
            Write-Warning 'More than 10 runbooks were found matching the input parameters you provided. Only the first 10 runbooks will be shown.'
            $runbooks = $runbooks[0..9]
        }

        #endregion

        #region Show each of the matching runbooks in the default browser.

        foreach ($runbook in $runbooks) {
            $uri = "${WebServiceEndpoint}:30091/#Workspaces/AutomationAdminExtension/Runbook/$($runbook.RunbookId)/$($View.ToLower())"
            Write-Verbose -Message "Opening '${uri}' in the default web browser."
            Start-Process -FilePath $uri
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Show-SmaPxRunbook
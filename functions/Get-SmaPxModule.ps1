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

function Get-SmaPxModule {
    [CmdletBinding(DefaultParameterSetName='ByName')]
    [OutputType('Orchestrator.WebService.Client.OaaSClient.Module')]
    param(
        [Parameter(Position=0, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('ModuleName')]
        [System.String[]]
        $Name = '*',

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('ModuleId')]
        [System.Guid[]]
        $Id,

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

        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                #region Get all modules from SMA.

                $modules = Get-SmaModule -Name * @connectionParameters

                #endregion

                if ($Name -match '^\*$') {
                    #region Return all modules.

                    $modules

                    #endregion
                } else {
                    #region Return modules that match one or more of the Name values, supporting wildcards and regardless of case.

                    :nextModule foreach ($module in $modules) {
                        foreach ($moduleName in $Name) {
                            if ($moduleName -match '[\*?]') {
                                if ($module.ModuleName -like $moduleName) {
                                    $module
                                    continue nextModule
                                }
                            } elseif ($module.ModuleName -eq $moduleName) {
                                $module
                                continue nextModule
                            }
                        }
                    }

                    #endregion
                }
                break
            }
            'ById' {
                #region Get modules using the native cmdlet (which works fine for guid lookup).

                Get-SmaModule -Id $Id @connectionParameters

                #endregion
                break
            }
        }

    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Export-ModuleMember -Function Get-SmaPxModule
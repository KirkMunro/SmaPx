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

function Update-SmaPxDefaultConnectionParameterSet {
    [CmdletBinding()]
    [OutputType([System.Void])]
    param()
    try {
        foreach ($commandName in $script:CommandsWithSmaConnectionParameters) {

            foreach ($smaConnectionParameterName in $script:SmaConnectionParameterNames) {

                #region Create the default parameter value identifier.

                $defaultParameterValueIdentifier = "${commandName}:${smaConnectionParameterName}"

                #endregion

                #region If the connection parameter is not null, apply it as default for the command; otherwise, remove the current default value.

                if ($script:ModuleConfig.$smaConnectionParameterName) {
                    $global:PSDefaultParameterValues[$defaultParameterValueIdentifier] = $script:ModuleConfig.$smaConnectionParameterName
                } elseif ($global:PSDefaultParameterValues.ContainsKey($defaultParameterValueIdentifier)) {
                    $global:PSDefaultParameterValues.Remove($defaultParameterValueIdentifier)
                }

                #endregion

            }

        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

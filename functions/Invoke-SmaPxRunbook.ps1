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

function Invoke-SmaPxRunbook {
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName='ByName')]
    [OutputType([System.Object])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookName')]
        [System.String]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('RunbookId')]
        [System.Guid]
        $Id,

        [Parameter(Mandatory=$true, ParameterSetName='Transient')]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.ScriptBlock]
        $ScriptBlock,

        [Parameter(ParameterSetName='Transient')]
        [System.Management.Automation.SwitchParameter]
        $SerializeOutput,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable]
        $Parameters,

        [Parameter()]
        [ValidateNotNull()]
        [ValidateRange(-1,3600)]
        [System.Int32]
        $Timeout = -1,

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
            #region Identify a transient runbook name that will be used if we're temporarily creating a runbook.

            $transientRunbookName = "Transient_$([System.Guid]::NewGuid().ToString('n'))"
            $transientRunbookSerializerName = "${transientRunbookName}_Serializer"

            #endregion

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

            #region Identify the passthru parameters parameter.

            $parametersParameter = @{}
            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Parameters')) {
                $parametersParameter['Parameters'] = $Parameters
            }

            #endregion

            #region Update the SerializeOutput parameter so that we're not dependent on the presence of a switch for later tests.

            $SerializeOutput = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('SerializeOutput') -and $SerializeOutput

            #endregion

            if ($PSCmdlet.ParameterSetName -eq 'Transient') {
                #region Create a new transient runbook from the script block.

                Write-Progress -Activity "Invoking SMA runbook ""${transientRunbookName}""" -Status "Creating runbook '${transientRunbookName}'..."
                $newRunbookParameters = @{
                           Name = $transientRunbookName
                    ScriptBlock = $scriptBlock
                    Description = 'This runbook was created by SmaPx for a one-time invocation. This runbook should only exist as a draft and never be published. It should be automatically removed once it finishes running.'
                            Tag = 'Transient'
                    LogProgress = 'Continue','Ignore' -contains $ProgressPreference
                     LogVerbose = 'Continue','Ignore' -contains $VerbosePreference
                       LogDebug = 'Continue','Ignore' -contains $DebugPreference
                }
                $runbook = New-SmaPxRunbook @newRunbookParameters @connectionParameters

                #endregion

                #region If serialization is required, create a serializer runbook.

                if ($SerializeOutput) {
                    #region Lookup the param block and PassThru parameters using the AST for the script block that was passed in.

                    $paramBlock = 'param()'
                    $passThruParameters = ''
                    if ($scriptBlock.Ast.ParamBlock) {
                        $paramBlock = $scriptBlock.Ast.ParamBlock.ToString()
                        foreach ($parameter in $scriptBlock.Ast.ParamBlock.Parameters) {
                            $passThruParameters += " -$($parameter.Name.VariablePath):$($parameter.Name.Extent)"
                        }
                    }

                    #endregion

                    #region Create a new serialization script block that will be used to serialize the results.

                    Write-Progress -Activity "Invoking SMA runbook ""${transientRunbookName}""" -Status 'Creating serialization script block...'
                    $serializerScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock(@"
    [CmdletBinding()]
    ${paramBlock}
    `$i = 0
    foreach (`$object in ${transientRunbookName}${passThruParameters}) {
        `$i++
        Write-Progress -Activity "Invoking runbook data serializer" -Status "Serializing object `${i}"
        InlineScript {
            [System.Management.Automation.PSSerializer]::Serialize(`$using:object)
        }
    }
"@)

                    #endregion

                    #region Create a new serialization runbook in SMA.

                    Write-Progress -Activity "Invoking SMA runbook ""${transientRunbookName}""" -Status "Creating runbook serializer '${transientRunbookSerializerName}'..."
                    $newRunbookParameters = @{
                               Name = $transientRunbookSerializerName
                        ScriptBlock = $serializerScriptBlock
                        Description = 'This runbook was created by SmaPx for a one-time invocation. This runbook should only exist as a draft and never be published. It should be automatically removed once it finishes running.'
                                Tag = 'Transient','Serializer'
                        LogProgress = 'Continue','Ignore' -contains $ProgressPreference
                         LogVerbose = 'Continue','Ignore' -contains $VerbosePreference
                           LogDebug = 'Continue','Ignore' -contains $DebugPreference
                    }
                    $runbook = New-SmaPxRunbook @newRunbookParameters @connectionParameters

                    #endregion
                }

                #endregion
            }
        } catch {
            #region If an exception was raised, remove the transient Runbook and its serializer if they exist.

            if ($PSCmdlet.ParameterSetName -eq 'Transient') {
                Remove-SmaRunbook -Name $transientRunbookName @connectionParameters
                if ($SerializeOutput) {
                    Remove-SmaRunbook -Name $transientRunbookSerializerName @connectionParameters
                }
            }

            #endregion

            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            switch ($PSCmdlet.ParameterSetName) {
                'Transient' {
                    #region Invoke the draft runbook or its serializer, depending on the parameters provided.

                    $testRunbookParameters = @{
                        'Name' = $(if ($SerializeOutput) {$transientRunbookSerializerName} else {$transientRunbookName})
                    }
                    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Parameters')) {
                        $testRunbookParameters['Parameters'] = $Parameters
                    }
                    Test-SmaPxRunbook @testRunbookParameters @connectionParameters

                    #endregion
                    break
                }
                default {
                    #region Identify the runbook id based on the parameter set that was used.

                    $smaRunbookId = $(if ($PSCmdlet.ParameterSetName -eq 'ById') {$Id} else {$Name})

                    #endregion

                    #region Identify the passthru lookup parameters.

                    $lookupParameters = @{}
                    foreach ($parameterName in 'Name','Id') {
                        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey($parameterName)) {
                            $lookupParameters[$parameterName] = $PSCmdlet.MyInvocation.BoundParameters[$parameterName]
                        }
                    }

                    #endregion

                    #region If the runbook failed to start, raise a terminating error.

                    Write-Progress -Activity "Invoking SMA runbook ""${smaRunbookId}""" -Status "Starting the runbook..."
                    if (-not ($job = Start-SmaPxRunbook @lookupParameters @parametersParameter @connectionParameters -WarningAction SilentlyContinue)) {
                        [System.String]$message = "Unable to start the '${smaRunbookId}' runbook. Invoke-SmaPxRunbook can only invoke published SMA runbooks. Make sure that the runbook exists and is published in SMA."
                        [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
                        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$smaRunbookId
                        throw $errorRecord
                    }

                    #endregion

                    #region If the runbook fails to complete in the time allowed, raise a terminating error.

                    if (-not ($job = Wait-SmaPxJob -Id $job.JobId -Timeout $Timeout @connectionParameters)) {
                        [System.String]$message = "Timeout exceeded. The '${smaRunbookId}' runbook failed to complete within ${Timeout} seconds."
                        [System.Management.Automation.RemoteException]$exception = New-Object -TypeName System.Management.Automation.RemoteException -ArgumentList $message
                        [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'RemoteException',([System.Management.Automation.ErrorCategory]::OperationTimeout),$smaRunbookId
                        throw $errorRecord
                    }

                    #endregion

                    #region Retrieve all output from the runbook.

                    Receive-SmaPxJob -Id $job.JobId @connectionParameters
                    Write-Progress -Activity "Invoking SMA runbook ""${smaRunbookId}""" -Status 'Runbook completed.' -Completed

                    #endregion
                    break
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        } finally {
            #region At this point we no longer need the transient runbook or the serializer runbook (if we created them).

            if ($PSCmdlet.ParameterSetName -eq 'Transient') {
                Remove-SmaRunbook -Name $transientRunbookName @connectionParameters
                if ($SerializeOutput) {
                    Remove-SmaRunbook -Name $transientRunbookSerializerName @connectionParameters
                }
            }

            #endregion
        }
    }
}

Export-ModuleMember -Function Invoke-SmaPxRunbook
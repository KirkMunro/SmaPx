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

function Wait-SmaPxJob {
    [CmdletBinding()]
    [OutputType('Microsoft.SystemCenter.ServiceManagementAutomation.Job')]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('JobId')]
        [System.Guid]
        $Id,

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

            #region Identify how long the command should sleep between tests for job completion.

            $sleepInterval = 1

            #endregion

            #region Identify any status values that are used when a SMA job is no longer running.

            $jobCompleteStatusValues = @(
                'Completed'
                'Failed'
                'Blocked'
                'Stopped'
                'Suspended'
            )

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process {
        try {
            #region Wait for the job to finish running.

            $timeElapsed = 0
            $smaJob = $null
            do {
                Write-Progress -Activity "Waiting on SMA job ""${Id}""" -Status "Waited ${timeElapsed} seconds for the runbook to complete..."
                try {
                    $smaJob = Get-SmaJob -Id $Id @connectionParameters
                } catch {
                }
                if (-not $smaJob) {
                    break
                }
                if ($jobCompleteStatusValues -contains $smaJob.JobStatus) {
                    break
                }
                Start-Sleep -Seconds $sleepInterval
                $timeElapsed += $sleepInterval
            } while (($Timeout -eq -1) -or ($timeElapsed -le $Timeout))
            Write-Progress -Activity "Waiting on SMA job ""${Id}""" -Completed

            #endregion

            #region If the job was not found, raise a terminating error.

            if (-not $smaJob) {
                [System.String]$message = "Job ""${Id}"" was not found."
                [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$Id
                throw $errorRecord
            }

            #endregion

            #endregion

            #region If the job raised an exception, raise a terminating error.

            if ($smaJob.JobException) {
                [System.String]$message = "Job '${Id}' threw an exception. $($smaJob.JobException)."
                [System.Management.Automation.RemoteException]$exception = New-Object -TypeName System.Management.Automation.RemoteException -ArgumentList $message
                [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'RemoteException',([System.Management.Automation.ErrorCategory]::InvalidResult),$smaJob.JobException
                throw $errorRecord
            }

            #endregion

            #region Return the job in its current state if it completed in the time allowed.

            if (($Timeout -eq -1) -or ($timeElapsed -le $Timeout)) {
                Write-Verbose -Message "Job ${Id} completed with a status of $($smaJob.JobStatus) in $('{0:0.###}' -f ($smaJob.EndTime - $smaJob.StartTime).TotalSeconds) seconds."
                $smaJob
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Wait-SmaPxJob
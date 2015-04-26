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

function Receive-SmaPxJob {
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('JobId')]
        [System.Guid]
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
            #region Initialize helper variables.

            $streamPrefixMatch = "^$([System.Text.RegularExpressions.Regex]::Escape($Id)):\[[^\]]+\]:"
            $streamPrefixReplaced = $false

            #endregion

            #region Retrieve all output from the job.

            $jobOutput = Get-SmaJobOutput -Id $Id -Stream Any @connectionParameters

            #endregion

            foreach ($jobOutputRecord in $jobOutput) {
                #region Remove the job id and computer name qualifiers from the output record.

                $streamText = $jobOutputRecord.StreamText
                if (-not $streamPrefixReplaced -and ($streamText -match $streamPrefixMatch)) {
                    $streamText = $streamText -replace $streamPrefixMatch
                    $streamPrefixReplaced = $true
                }

                #endregion

                #region Remove any trailing whitespace from the output record.

                $streamText = $streamText -split "`n" -replace '\s+$' -join "`n"

                #endregion

                switch ($jobOutputRecord.StreamTypeName) {
                    'Progress' {
                        #region Write a progress record.

                        $progressRecord = @{}
                        $progressProperties = $streamText -split "`n" -split '^([^:]+):\s+' -replace '^\s+|\s+$' -join "`n" -replace '^\s+|\s+$' -split "(?m:`n{2,})"
                        foreach ($progressProperty in $progressProperties) {
                            $tokens = $progressProperty -split "`n"
                            $propertyName = $tokens[0]
                            $propertyValue = $tokens[1..$($tokens.Count - 1)] -join ' '
                            if ($propertyValue -as [System.Int32]) {
                                $propertyValue = $propertyValue -as [System.Int32]
                            }
                            $progressRecord[$propertyName] = $propertyValue
                        }
                        Write-Progress -Activity $progressRecord.Activity -Id $progressRecord.ActivityId -ParentId $progressRecord.ParentActivityId -Status $progressRecord.StatusDescription -SecondsRemaining $progressRecord.SecondsRemaining -PercentComplete $progressRecord.PercentComplete -CurrentOperation $progressRecord.CurrentOperation -Completed:$($progressRecord.RecordType -eq 'Completed')

                        #endregion
                        break
                    }

                    'Verbose' {
                        #region Write the verbose message.

                        Write-Verbose -Message $streamText

                        #endregion
                        break
                    }

                    'Debug' {
                        #region Write the debug message.

                        Write-Debug -Message $streamText

                        #endregion
                        break
                    }

                    'Warning' {
                        #region Write the warning message.

                        Write-Warning -Message $streamText

                        #endregion
                        break
                    }

                    'Error' {
                        #region Identify the background and foreground colors to use for the error message.

                        switch ($Host.Name) {
                            'Windows PowerShell ISE Host' {
                                $writeHostColors = @{}
                                foreach ($position in 'Foreground','Background') {
                                    switch ($psISE.Options."Error${position}Color") {
                                        ([System.Windows.Media.Colors]::Transparent) {
                                            break
                                        }
                                        ([System.Windows.Media.Colors]::Olive) {
                                            $writeHostColors["${position}Color"] = [System.ConsoleColor]::DarkYellow
                                            break
                                        }
                                        default {
                                            foreach ($color in 'Black','DarkBlue','DarkGreen','DarkCyan','DarkRed','DarkMagenta','Gray','DarkGray','Blue','Green','Cyan','Red','Magenta','Yellow','White') {
                                                if ($psISE.Options."Error${position}Color" -eq [System.Windows.Media.Colors]::$color) {
                                                    $writeHostColors["${position}Color"] = [System.ConsoleColor]::$color
                                                    break
                                                }
                                            }
                                            break
                                        }
                                    }
                                }
                                break
                            }
                            'ConsoleHost' {
                                $writeHostColors = @{
                                    ForegroundColor = $Host.PrivateData.ErrorForegroundColor
                                    BackgroundColor = $Host.PrivateData.ErrorBackgroundColor
                                }
                                break
                            }
                            default {
                                $writeHostColors = @{}
                                break
                            }
                        }

                        #endregion

                        #region Write the error message to the host directly using Write-Host.

                        # We use Write-Host instead of Write-Error because the error text from the output record is
                        # already qualified with an error label and position information relative to the runbook. We
                        # don't want to then pollute that with error information relative to this command, so the
                        # Write-Host command is the way to go.
                        Write-Host $streamText @writeHostColors

                        #endregion
                        break
                    }

                    'Output' {
                        #region If the output content is a serialized object, deserialize it; otherwise, output the text.

                        if ($streamText -match '(?s)^\<Objs.+\</Objs\>$') {
                            [System.Management.Automation.PSSerializer]::Deserialize($streamText)
                        } else {
                            Write-Output -InputObject $streamText
                        }

                        #endregion
                        break
                    }
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Export-ModuleMember -Function Receive-SmaPxJob
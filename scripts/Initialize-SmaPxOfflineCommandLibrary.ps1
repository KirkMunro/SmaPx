<#############################################################################
The ScsmPx module facilitates automation with Microsoft System Center Service
Manager by auto-loading the native modules that are included as part of that
product and enabling automatic discovery of the commands that are contained
within the native modules. It also includes dozens of complementary commands
that are not available out of the box to allow you to do much more with your
PowerShell automation efforts using the platform.

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

#region Return immediately if invoked from an Orchestrator.Sandbox process.

# Don't use a variable here, just reference the object directly in brackets so that we don't leave crumbs lying around
if ((Get-Process -Id $PID).Name -eq 'Orchestrator.Sandbox') {
    return
}

#endregion

#region Define functions that are normally only available within an SMA runbook worker's process.

# We only define these if they are not already defined (from another module -- don't want to break compatibility).
# Also take care in this section to not define variables as they will be in the global scope, and we want to avoid
# leaving crumbs around.

if ((Get-Command -Name Get-AutomationCertificate -ErrorAction SilentlyContinue) -and ((Get-Command -Name Get-AutomationCertificate).ModuleName)) {
    Write-Verbose -Message "Get-AutomationCertificate is already defined in module '$((Get-Command -Name Get-AutomationCertificate).ModuleName)'. It will not be re-created."
} else {
    function Get-AutomationCertificate {
        [CmdletBinding()]
        [OutputType([System.Object])]
        param(
            [Parameter(Position=0, Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name,

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

            [Parameter(Position=1)]
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

            #region Define the workflow that will be used to retrieve the certificate from SMA.

            $getAutomationCertificateWorkflow = {
                [CmdletBinding()]
                param(
                    [Parameter(Position=0, Mandatory=$true)]
                    [System.String]
                    $Name
                )
                $certificate = Get-AutomationCertificate -Name $Name
                if (-not $certificate) {
                    # Raise a terminating error if the certificate was not found on the SMA server
                    throw "Unable to find certificate '${Name}' on the SMA server. Add the certificate to the SMA asset store and then try again."
                }
                $certificate.Thumbprint
            }

            #endregion

            #region Retrieve the certificate thumbprint and look up the certificate on the local file system.

            if ($thumbprint = Invoke-SmaPxRunbook -ScriptBlock $getAutomationCertificateWorkflow -Parameters @{Name = $Name} -SerializeOutput @connectionParameters) {
                if ($certificate = Get-Item -Path Certificate::\*\*\${thumbprint} | Select-Object -Unique) {
                    $certificate
                } else {
                    # Raise a terminating error if the certificate was not found on the local file system
                    [System.String]$message = "Unable to find certificate with thumbprint '${thumbprint}' on the local computer. Make sure you have the certificate added to your local certificate store and then try again."
                    [System.Management.Automation.ItemNotFoundException]$exception = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
                    [System.Management.Automation.ErrorRecord]$errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception,'ItemNotFoundException',([System.Management.Automation.ErrorCategory]::ObjectNotFound),$thumbprint
                    throw $errorRecord
                }
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

if ((Get-Command -Name Get-AutomationConnection -ErrorAction SilentlyContinue) -and ((Get-Command -Name Get-AutomationConnection).ModuleName)) {
    Write-Verbose -Message "Get-AutomationConnection is already defined in module '$((Get-Command -Name Get-AutomationConnection).ModuleName)'. It will not be re-created."
} else {
    function Get-AutomationConnection {
        [CmdletBinding()]
        [OutputType([System.Object])]
        param(
            [Parameter(Position=0, Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name,

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

            [Parameter(Position=1)]
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

            #region Define the workflow that will be used to retrieve the connection from SMA.

            $getAutomationConnectionWorkflow = {
                [CmdletBinding()]
                param(
                    [Parameter(Position=0, Mandatory=$true)]
                    [System.String]
                    $Name
                )
                $connection = Get-AutomationConnection -Name $Name
                if (-not $connection) {
                    # Raise a terminating error if the connection was not found on the SMA server
                    throw "Unable to find connection '${Name}' on the SMA server. Add the connection to the SMA asset store and then try again."
                }
                $connection
            }

            #endregion

            #region Retrieve the connection object from SMA.

            Invoke-SmaPxRunbook -ScriptBlock $getAutomationConnectionWorkflow -Parameters @{Name = $Name} -SerializeOutput @connectionParameters

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

if ((Get-Command -Name Get-AutomationPSCredential -ErrorAction SilentlyContinue) -and ((Get-Command -Name Get-AutomationPSCredential).ModuleName)) {
    Write-Verbose -Message "Get-AutomationPSCredential is already defined in module '$((Get-Command -Name Get-AutomationPSCredential).ModuleName)'. It will not be re-created."
} else {
    function Get-AutomationPSCredential {
        [CmdletBinding()]
        [OutputType([System.Management.Automation.PSCredential])]
        param(
            [Parameter(Position=0, Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name,

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

            [Parameter(Position=1)]
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

            #region Define the workflow that will be used to retrieve the PSCredential from SMA.

            $getAutomationPSCredentialWorkflow = {
                [CmdletBinding()]
                param(
                    [Parameter(Position=0, Mandatory=$true)]
                    [System.String]
                    $Name
                )
                $credential = Get-AutomationPSCredential -Name $Name
                if (-not $credential) {
                    # Raise a terminating error if the PSCredential was not found on the SMA server
                    throw "Unable to find credential '${Name}' on the SMA server. Add the credential to the SMA asset store and then try again."
                }
                @{
                    UserName = $credential.UserName
                    Password = $credential.GetNetworkCredential().Password
                }
            }

            #endregion

            #region Retrieve the credential information from SMA and convert it into a PSCredential object.

            if ($plainTextCredential = Invoke-SmaPxRunbook -ScriptBlock $getAutomationPSCredentialWorkflow -Parameters @{Name = $Name} -SerializeOutput @connectionParameters) {
                $secureStringPassword = ConvertTo-SecureString -String $plainTextCredential.Password -AsPlainText -Force
                New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $plainTextCredential.UserName,$secureStringPassword
            }

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

if ((Get-Command -Name Get-AutomationVariable -ErrorAction SilentlyContinue) -and ((Get-Command -Name Get-AutomationVariable).ModuleName)) {
    Write-Verbose -Message "Get-AutomationVariable is already defined in module '$((Get-Command -Name Get-AutomationVariable).ModuleName)'. It will not be re-created."
} else {
    function Get-AutomationVariable {
        [CmdletBinding()]
        [OutputType([System.Object])]
        param(
            [Parameter(Position=0, Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name,

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

            [Parameter(Position=1)]
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

            #region Define the workflow that will be used to retrieve the variable from SMA.

            $getAutomationVariableWorkflow = {
                [CmdletBinding()]
                param(
                    [Parameter(Position=0, Mandatory=$true)]
                    [System.String]
                    $Name,

                    [Parameter()]
                    [System.Boolean]
                    $AllowNull = $false
                )
                $variable = Get-AutomationVariable -Name $Name
                if (-not $AllowNull -and -not $variable) {
                    # Raise a terminating error if the variable was not found on the SMA server
                    throw "Unable to find variable '${Name}' on the SMA server. Add the variable to the SMA asset store and then try again."
                }
                $variable
            }

            #endregion

            #region Retrieve the variable value from SMA.

            $variableExists = (Get-SmaVariable -Name $Name @connectionParameters) -ne $null
            Invoke-SmaPxRunbook -ScriptBlock $getAutomationVariableWorkflow -Parameters @{Name = $Name; AllowNull = $variableExists} -SerializeOutput @connectionParameters

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

if ((Get-Command -Name Set-AutomationVariable -ErrorAction SilentlyContinue) -and ((Get-Command -Name Set-AutomationVariable).ModuleName)) {
    Write-Verbose -Message "Set-AutomationVariable is already defined in module '$((Get-Command -Name Set-AutomationVariable).ModuleName)'. It will not be re-created."
} else {
    function Set-AutomationVariable {
        [CmdletBinding()]
        [OutputType([System.Void])]
        param(
            [Parameter(Position=0, Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name,

            [Parameter(Position=1, Mandatory=$true)]
            [System.Object]
            $Value,

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

            [Parameter(Position=1)]
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

            #region Define the workflow that will be used to set the variable in SMA.

            $setAutomationVariableWorkflow = {
                [CmdletBinding()]
                param(
                    [Parameter(Position=0, Mandatory=$true)]
                    [System.String]
                    $Name,

                    [Parameter(Position=1, Mandatory=$true)]
                    [System.Object]
                    $Value
                )
                Set-AutomationVariable -Name $Name -Value $Value
            }

            #endregion

            #region Set the variable value in SMA.

            Invoke-SmaPxRunbook -ScriptBlock $setAutomationVariableWorkflow -Parameters @{Name = $Name; Value = $Value} @connectionParameters

            #endregion
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

#endregion
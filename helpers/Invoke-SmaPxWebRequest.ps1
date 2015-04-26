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

function Invoke-SmaPxWebRequest {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Object])]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $RelativeUri,

        [Parameter()]
        [ValidateNotNull()]
        [Microsoft.PowerShell.Commands.WebRequestMethod]
        $Method,

        [Parameter()]
        [ValidateNotNull()]
        [System.Collections.Hashtable]
        $Headers,

        [Parameter()]
        [ValidateNotNull()]
        [System.Object]
        $Body
    )
    try {
        #region Copy the bound parameters to a PSPassThruParameters parameter hashtable.

        [System.Collections.Hashtable]$PSPassThruParameters = $PSCmdlet.MyInvocation.BoundParameters

        #endregion

        #region Remove the RelativeUri parameter from the PassThru parameter set.

        $PSPassThruParameters.Remove('RelativeUri') > $null

        #endregion

        #region Add additional required parameters to the PSPassThruParameters hashtable.

        # Build the Uri to the REST API (port 9090)
        $uri = "$($script:ModuleConfig.WebServiceEndpoint):9090/00000000-0000-0000-0000-000000000000/$($RelativeUri -replace '^/')"
        # If we have non-empty credentials, then use them (basic authentication); otherwise,
        # use Windows authentication
        if ($script:ModuleConfig.Credential -and ($script:ModuleConfig.Credential -ne [System.Management.Automation.PSCredential]::Empty)) {
            $PSPassThruParameters['Credential'] = $script:ModuleConfig.Credential
        } else {
            $PSPassThruParameters['UseDefaultCredentials'] = $true
        }
        # Basic parsing is used so that this will even work on Server Core
        $PSPassThruParameters['UseBasicParsing'] = $true
        # If the method is Post and we don't have a body yet, create one.
        if (($Method -eq 'Post') -and -not $PSPassThruParameters.ContainsKey('Body')) {
            $PSPassThruParameters['Body'] = '{}'
        }
        # Set the default value for the headers if it is not already set.
        if (-not $PSPassThruParameters.ContainsKey('Headers')) {
            $PSPassThruParameters['Headers'] = @{}
        }

        #endregion

        #region Create the SslCertificateHelper class if it does not exist.

        # This policy class allows us to ignore SSL trust issues for self-signed certificates on our SMA server.
        if (-not ('PowerShell.TypeExtensions.SslCertificateHelper' -as [System.Type])) {
            $cSharpCode = @'
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

namespace PowerShell {

    namespace TypeExtensions {

        public class SslCertificateHelper {

            public static bool VerifyValidOrSelfSigned(
                object sender,
                X509Certificate certificate,
                X509Chain chain,
                SslPolicyErrors sslPolicyErrors)
            {
                if (sslPolicyErrors == SslPolicyErrors.None)
                {
                    // Valid certificate
                    return true;
                }

                if ((sslPolicyErrors & SslPolicyErrors.RemoteCertificateChainErrors) == SslPolicyErrors.RemoteCertificateChainErrors)
                {
                    if (certificate.Subject == certificate.Issuer)
                    {
                        // In self-signed certificates, the subject and the issuer are the same
                        bool chainError = false;
                        foreach (X509ChainStatus chainStatus in chain.ChainStatus)
                        {
                            switch (chainStatus.Status)
                            {
                                case X509ChainStatusFlags.NoError:
                                    chainError |= false;
                                    break;

                                case X509ChainStatusFlags.UntrustedRoot:
                                    // Self-signed certificates have untrusted roots
                                    chainError |= false;
                                    break;

                                default:
                                    chainError |= true;
                                    break;
                            }
                        }
                        return !chainError;
                    }
                }

                // If the other tests didn't pass, return false
                return false;
            }

            public static void AllowSelfSignedCertificates()
            {
                ServicePointManager.ServerCertificateValidationCallback = VerifyValidOrSelfSigned;
            }

            public static void DenySelfSignedCertificates()
            {
                ServicePointManager.ServerCertificateValidationCallback = null;
            }
        }
    }
}
'@

            Add-Type -TypeDefinition $cSharpCode
        }

        #endregion

        #region Lookup the self-signed certificate flag value.

        $allowSelfSignedCertificate = $false
        $smaModuleRoot = (Get-Module -Name Microsoft.SystemCenter.ServiceManagementAutomation).ModuleBase
        if (Test-Path -LiteralPath ${smaModuleRoot}\Authentication.config) {            $smaAuthenticationConfig = [xml](Get-Content -LiteralPath ${smaModuleRoot}\Authentication.config)            if (($acceptSelfSignedCertificateElement = $smaAuthenticationConfig.GetElementsByTagName('add') | Where-Object {$_.key -eq 'AcceptSelfSignedCertificate'}) -and                ($acceptSelfSignedCertificateElement.value -eq 'True')) {                $allowSelfSignedCertificate = $true            }        }

        #endregion

        #region Invoke the Invoke-WebRequest command, being careful to handle certificates properly.

        try {
            if ($allowSelfSignedCertificate) {
                [PowerShell.TypeExtensions.SslCertificateHelper]::AllowSelfSignedCertificates()
            }
            if ($Method -eq 'Get') {
                if ($uri -match '/\$value$') {
                    # If the Accept header was not provided, add an accept header to indicate we want our output to be an octet stream
                    if (-not $PSPassThruParameters.Headers.ContainsKey('Accept')) {
                        $PSPassThruParameters.Headers['Accept'] = 'application/octet-stream;charset=utf-8'
                    }
                    Write-Progress -Activity 'Invoking web request' -Status "Retrieving results from ${uri}..."
                    if ($webResults = Invoke-WebRequest -Uri $uri @PSPassThruParameters) {
                        [pscustomobject]@{
                            Resource = [System.Text.Encoding]::UTF8.GetString($webResults.Content)
                                ETag = $webResults.Headers.ETag
                        }
                    }
                } else {
                    # If the Accept header was not provided, add an accept header to indicate we want our output to be in JSON format
                    if (-not $PSPassThruParameters.Headers.ContainsKey('Accept')) {
                        $PSPassThruParameters.Headers['Accept'] = 'application/json;odata=verbose'
                    }
                    $objectsRetrieved = $objectCount = 0
                    $page = 1
                    do {
                        Write-Progress -Activity 'Invoking web request' -Status "Retrieving page ${page} of results from ${uri}..."
                        if (($webResults = Invoke-WebRequest -Uri "${uri}?`$skip=${objectsRetrieved}&`$top=50&`$inlinecount=allpages" @PSPassThruParameters) -and
                            $webResults.Content -and
                            ($resultData = ConvertFrom-Json -InputObject $webResults.Content)) {
                            $objectCount = $resultData.d.__count
                            $objectsRetrieved += $resultData.d.results.Count
                            $page++
                            foreach ($record in $resultData.d.results) {
                                if ((Get-Member -InputObject $record -Name __metadata -ErrorAction SilentlyContinue) -and
                                    (Get-Member -InputObject $record.__metadata -Name type -ErrorAction SilentlyContinue)) {
                                    Add-Member -InputObject $record -TypeName $record.__metadata.type -PassThru
                                } else {
                                    $record
                                }
                            }
                        }
                    } until ($objectsRetrieved -eq $objectCount)
                    Write-Progress -Activity 'Invoking web request' -Status "${objectsRetrieved} objects were retrieved." -Completed
                }
            } elseif ($PSCmdlet.ShouldProcess($uri, $Method)) {
                # If the Content-Type header was not provided, add a content-type header to indicate our input is in JSON format
                if (-not $PSPassThruParameters.Headers.ContainsKey('Content-Type')) {
                    $PSPassThruParameters.Headers['Content-Type'] = 'application/json;odata=verbose'
                }
                # If the Accept header was not provided, add an accept header to indicate we want our output to be in JSON format
                if (-not $PSPassThruParameters.Headers.ContainsKey('Accept')) {
                    $PSPassThruParameters.Headers['Accept'] = 'application/json;odata=verbose'
                }
                Write-Progress -Activity 'Invoking web request' -Status "Invoking ${Method} method against target ${uri}..."
                if (($webResults = Invoke-WebRequest -Uri $uri @PSPassThruParameters) -and
                    $webResults.Content) {
                    Write-Progress -Activity 'Invoking web request' -Status 'Converting results from JSON...'
                    ConvertFrom-Json -InputObject $webResults.Content
                }
                Write-Progress -Activity 'Invoking web request' -Status "${Method} invocation completed successfully." -Completed
            }
        } catch [System.Net.WebException] {
            # If we have an error message in JSON format, convert the JSON format error to plain text
            # and then re-throw the error
            Set-StrictMode -Off
            if ($_.ErrorDetails -and
                ($errorDetails = ConvertFrom-Json -InputObject $_.ErrorDetails -ErrorAction SilentlyContinue) -and
                ($errorMessage = $errorDetails.error.message.value)) {
                $_.ErrorDetails = $errorMessage
                if ($innerErrorMessage = $errorDetails.error.innererror.message) {
                    $_.ErrorDetails = "$($_.ErrorDetails.Message) ${innerErrorMessage}"
                }
                if ($errorCode = $errorDetails.error.code) {
                    $_.ErrorDetails = "$($_.ErrorDetails.Message) Error code ${errorCode}."
                }
            }
            throw $_
        } finally {
            [PowerShell.TypeExtensions.SslCertificateHelper]::DenySelfSignedCertificates()
        }

        #endregion
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
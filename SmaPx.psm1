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

try {
    #region Initialize the module.

    Invoke-Snippet -Name Module.Initialize

    #endregion

    #region If PowerShell erroneously created a New-SmaPortableModule module or an Initialize-SmaPxOfflineCommandLibrary module, remove them.

    # This is a workaround to a bug in PowerShell 3.0 and later.
    foreach ($moduleName in 'New-SmaPortableModule','Initialize-SmaPxOfflineCommandLibrary') {
        if (Get-Module -Name $moduleName) {
            Remove-Module -Name $moduleName
        }
    }

    #endregion

    #region Import helper (private) function definitions.

    Invoke-Snippet -Name ScriptFile.Import -Parameters @{
        Path = Join-Path -Path $PSModuleRoot -ChildPath helpers
    }

    #endregion

    #region Import public function definitions.

    Invoke-Snippet -Name ScriptFile.Import -Parameters @{
        Path = Join-Path -Path $PSModuleRoot -ChildPath functions
    }

    #endregion

    #region Add type extensions for SMA types.

    function Test-PropertyDefined {
        [CmdletBinding()]
        [OutputType([System.Boolean])]
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $TypeName,

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name
        )
        try {
           ((($type = $TypeName -as [System.Type]) -and             ($property = $type.GetProperty($Name)) -and             ($property.DeclaringType -eq $type)) -or            (($typeData = Get-TypeData -TypeName $TypeName) -and             (($typeData.Members.ContainsKey($Name)) -or              ((Get-Member -InputObject $typeData -Name $Name -ErrorAction SilentlyContinue) -and               ($typeData.$Name)))))        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    function Test-MethodDefined {
        [CmdletBinding()]
        [OutputType([System.Boolean])]
        param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $TypeName,

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name
        )
        try {
           ((($type = $TypeName -as [System.Type]) -and             ($method = $type.GetMethod($Name)) -and             ($method.DeclaringType -eq $type)) -or            (($typeData = Get-TypeData -TypeName $TypeName) -and             ($typeData.Members.ContainsKey($Name))))        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    if (-not (Test-PropertyDefined -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook -Name AuthoringStatus)) {        Update-TypeData -MemberType ScriptProperty -MemberName AuthoringStatus -Value {            if ($this.PublishedRunbookVersionID) {                if ($this.DraftRunbookVersionID) {                    'InEdit'                } else {                    'Published'                }            } else {                'New'            }        } -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook    }
    if (-not (Test-PropertyDefined -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook -Name TagsCollection)) {        Update-TypeData -MemberType ScriptProperty -MemberName TagsCollection -Value {            $this.Tags -split ','        } -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook    }
    if (-not (Test-PropertyDefined -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook -Name Name)) {        Update-TypeData -MemberType AliasProperty -MemberName Name -Value RunbookName -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook    }
    if (-not (Test-PropertyDefined -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook -Name Id)) {        Update-TypeData -MemberType AliasProperty -MemberName Id -Value RunbookID -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook    }
    if (-not (Test-MethodDefined -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook -Name ToString)) {        Update-TypeData -MemberType ScriptMethod -MemberName ToString -Value {$this.RunbookName} -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook    }    if (-not (Test-PropertyDefined -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook -Name DefaultDisplayPropertySet)) {        Update-TypeData -DefaultDisplayPropertySet @(            'RunbookName'            'RunbookID'            'AuthoringStatus'        ) -TypeName Orchestrator.WebService.Client.OaaSClient.Runbook    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name RunbookName)) {        Update-TypeData -MemberType ScriptProperty -MemberName RunbookName -Value {            if (($scriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock($this.Content)) -and                ($workflowDefinition = $scriptBlock.Ast.Find({$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]},$false))) {                $workflowDefinition.Name            }        } -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name RunbookID)) {        Update-TypeData -MemberType ScriptProperty -MemberName RunbookID -Value {$this.RunbookVersion.RunbookID} -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name RunbookVersionID)) {        Update-TypeData -MemberType ScriptProperty -MemberName RunbookVersionID -Value {$this.RunbookVersion.RunbookVersionID} -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name VersionNumber)) {        Update-TypeData -MemberType ScriptProperty -MemberName VersionNumber -Value {$this.RunbookVersion.VersionNumber} -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name IsDraft)) {        Update-TypeData -MemberType ScriptProperty -MemberName IsDraft -Value {$this.RunbookVersion.IsDraft} -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name CreationTime)) {        Update-TypeData -MemberType ScriptProperty -MemberName CreationTime -Value {$this.RunbookVersion.CreationTime} -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name LastModifiedTime)) {        Update-TypeData -MemberType ScriptProperty -MemberName LastModifiedTime -Value {$this.RunbookVersion.LastModifiedTime} -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }
    if (-not (Test-PropertyDefined -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition -Name DefaultDisplayPropertySet)) {        Update-TypeData -DefaultDisplayPropertySet @(            'RunbookName'            'VersionNumber'            'IsDraft'        ) -TypeName Microsoft.SystemCenter.ServiceManagementAutomation.RunbookDefinition    }    if (-not (Test-PropertyDefined -TypeName Orchestrator.ResourceModel.RunbookParameter -Name DefaultDisplayPropertySet)) {        Update-TypeData -DefaultDisplayPropertySet @(            'Name'            'Type'            'IsMandatory'            'Position'        ) -TypeName Orchestrator.ResourceModel.RunbookParameter    }    if (-not (Test-PropertyDefined -TypeName Orchestrator.ResourceModel.RunbookParameter -Name DefaultKeyPropertySet)) {        Update-TypeData -DefaultKeyPropertySet @(            'Position'        ) -TypeName Orchestrator.ResourceModel.RunbookParameter    }    #endregion

    #region Identify the SMA connection parameters and a list of commands that use them.

    $SmaConnectionParameterNames = @('WebServiceEndpoint','Port','AuthenticationType','Credential')
    $CommandsWithSmaConnectionParameters = @(Get-Command -Module Microsoft.SystemCenter.ServiceManagementAutomation | Select-Object -ExpandProperty Name)
    $CommandsWithSmaConnectionParameters += @(
        # Offline SMA command library
        'Get-AutomationCertificate'
        'Get-AutomationConnection'
        'Get-AutomationPSCredential'
        'Get-AutomationVariable'
        'Set-AutomationVariable'
        # SmaPx commands
        'Edit-SmaPxRunbook'
        'Get-SmaPxModule'
        'Get-SmaPxRunbook'
        'Get-SmaPxRunbookParameter'
        'Get-SmaPxRunbookVersion'
        'Invoke-SmaPxRunbook'
        'New-SmaPxRunbook'
        'Receive-SmaPxJob'
        'Remove-SmaPxRunbook'
        'Set-SmaPxRunbook'
        'Show-SmaPxDashboard'
        'Show-SmaPxRunbook'
        'Start-SmaPxRunbook'
        'Test-SmaPxRunbook'
        'Wait-SmaPxJob'
    )

    #endregion

    #region Identify the SMA sandbox location.

    $SmaSandboxPath = Join-Path -Path ([System.Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\SmaSandbox
    $SmaSandboxTags = Join-Path -Path $SmaSandboxPath -ChildPath _tags.clixml

    #endregion

    #region Load the connection info if it was previously cached (but only if we are not in a runbook worker process).

    if (Test-SmaPxRunbookWorker) {
        $ModuleConfig = [pscustomobject]@{
            WebServiceEndpoint = $null
                          Port = $null
            AuthenticationType = $null
                    Credential = $null
        }
        $ModuleConfig.PSTypeNames.Insert(0,'SmaPx.ConnectionInfo')
        $ModuleConfigFolder = Join-Path -Path ([System.Environment]::GetFolderPath('ApplicationData')) -ChildPath Provance\SmaPx
        $ModuleConfigFile = Join-Path -Path $ModuleConfigFolder -ChildPath Config.ps1xml
        if (Test-Path -LiteralPath $ModuleConfigFile) {
            $ModuleConfig = Import-Clixml -LiteralPath $ModuleConfigFile
            # Workaround the incorrect -Credential parameter support in SMA by converting from string to PSCredential here
            if ($ModuleConfig.Credential) {
                $ModuleConfig.Credential = Get-Credential -Credential $ModuleConfig.Credential
            }
            Update-SmaPxDefaultConnectionParameterSet
        }
    }

    #endregion
} catch {
    throw
}

$PSModule.OnRemove = {
    #region On unload, remove the PSDefaultParameterValues we set for the SMA cmdlets.

    if (Test-SmaPxRunbookWorker) {
        $script:ModuleConfig.WebServiceEndpoint = $null
        $script:ModuleConfig.Port = $null
        $script:ModuleConfig.AuthenticationType = $null
        $script:ModuleConfig.Credential = $null
        Update-SmaPxDefaultConnectionParameterSet
    }

    #endregion

    #region Also remove the offline command library that was created on import.

    foreach ($commandName in @('Get-AutomationCertificate','Get-AutomationConnection','Get-AutomationPSCredential','Get-AutomationVariable','Set-AutomationVariable')) {
        if (($command = Get-Command -Name $commandName -ErrorAction SilentlyContinue) -and -not $command.ModuleName) {
            Remove-Item -LiteralPath Function::${commandName}
        }
    }

    #endregion
}
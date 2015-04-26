## SmaPx

### Overview

The SmaPx module provides a rich set of commands that extend the automation
capabilities of Microsoft System Center Service Management Automation (SMA).
These commands offer additional value that is not natively available out of
the box to allow you to do much more with your PowerShell automation efforts
using the platform.

### Minimum requirements

- PowerShell 3.0
- SnippetPx module

### License and Copyright

Copyright 2015 Provance Technologies

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

### Installing the SmaPx module

SmaPx is dependent on the SnippetPx module. You can download and install the
latest versions of SmaPx and SnippetPx using any of the following methods:

#### PowerShellGet

If you don't know what PowerShellGet is, it's the way of the future for PowerShell
package management. If you're curious to find out more, you should read this:
<a href="http://blogs.msdn.com/b/mvpawardprogram/archive/2014/10/06/package-management-for-powershell-modules-with-powershellget.aspx" target="_blank">Package Management for PowerShell Modules with PowerShellGet</a>

Note that these commands require that you have the PowerShellGet module installed
on the system where they are invoked.

```powershell
# If you don’t have SmaPx installed already and you want to install it for all
# all users (recommended, requires elevation)
Install-Module SmaPx,SnippetPx

# If you don't have SmaPx installed already and you want to install it for the
# current user only
Install-Module SmaPx,SnippetPx -Scope CurrentUser

# If you have SmaPx installed and you want to update it
Update-Module
```

#### PowerShell 3.0 or Later

To install from PowerShell 3.0 or later, open a native PowerShell console (not ISE,
unless you want it to take longer), and invoke one of the following commands:

```powershell
# If you want to install SmaPx for all users or update a version already installed
# (recommended, requires elevation for new install for all users)
& ([scriptblock]::Create((iwr -uri http://tinyurl.com/Install-GitHubHostedModule).Content)) -ModuleName SmaPx,SnippetPx

# If you want to install SmaPx for the current user
& ([scriptblock]::Create((iwr -uri http://tinyurl.com/Install-GitHubHostedModule).Content)) -ModuleName SmaPx,SnippetPx -Scope CurrentUser
```

### How to load the module

To load the SmaPx module into PowerShell, invoke the following command:

```powershell
Import-Module -Name SmaPx
```

This command is not necessary if you are running Microsoft Windows
PowerShell 3.0 or later and if module auto-loading is enabled (default).

### SmaPx Commands

There are 19 commands available in the SmaPx module today, and 40 cmdlets
in the native SMA module, offering a total of 59 commands to make it easier
to perform automation with Microsoft System Center Service Management
Automation. To see a list of all of the commands that are available in the
SmaPx modules, invoke the following command:

```powershell
Get-Command -Module SmaPx
```

That command will return a list of commands that are included in the
SmaPx module. Note that all SmaPx module commands start with the SmaPx
noun prefix.

###  Managing Microsoft System Center Service Management Automation with SmaPx

TODO

### Command List

The SmaPx module currently includes the following commands:

```powershell
Edit-SmaPxRunbook
Get-SmaPxConnectionInfo
Get-SmaPxModule
Get-SmaPxRunbook
Get-SmaPxRunbookParameter
Get-SmaPxRunbookVersion
Invoke-SmaPxRunbook
New-SmaPxRunbook
Receive-SmaPxJob
Remove-SmaPxRunbook
Reset-SmaPxConnectionInfo
Set-SmaPxConnectionInfo
Set-SmaPxRunbook
Show-SmaPxDashboard
Show-SmaPxRunbook
Start-SmaPxRunbook
Test-SmaPxRunbook
Test-SmaPxRunbookWorker
Wait-SmaPxJob
```
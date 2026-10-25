# ![Exchange_Narrow_Blue_PowerShell](https://github.com/rgel/Exchange/assets/6964549/a8380f46-2c64-4a8f-ad8a-a2e9de90f04d)$${\color{blue}Exchange \space PowerShell \space Repo}$$

### $${\color{green}MODULES}$$

### [<ins>Power-EXCH</ins>](https://github.com/rgel/Exchange/tree/main/Power-EXCH)

> [!NOTE]
> [<b>Exchange Management Shell</b>](https://learn.microsoft.com/en-us/powershell/exchange/open-the-exchange-management-shell?view=exchange-ps) is a preferred method for connecting to Exchange servers\
> But it is not required, a remote [<b>PSSession</b>](https://learn.microsoft.com/en-us/powershell/exchange/connect-to-exchange-servers-using-remote-powershell?view=exchange-ps) is good enough

+ To install this module, drop the entire `Power-EXCH` folder into one of your module directories

+ The default PowerShell module paths are listed in the `$env:PSModulePath` environment variable

+ To make it look better, split the paths in this manner: `$env:PSModulePath -split ';'`

+ The default per-user module path is: `"$env:HOMEDRIVE$env:HOMEPATH\Documents\WindowsPowerShell\Modules"`

+ The default computer-level module path is: `"$env:windir\System32\WindowsPowerShell\v1.0\Modules"`

+ To use the module, type following command: `Import-Module Power-EXCH -Force -Verbose`

+ To see the commands imported, type `Get-Command -Module Power-EXCH`

+ For help on each individual cmdlet or function, run `Get-Help CmdletName -Full [-Online][-Examples]`

> [!TIP]
> To start using the module functions:

+ Open <b>EMS</b> console. To open <b>EMS</b> on Core Server, type `LaunchEMS` in the console
+ If you have no <b>EMS</b>, please install [<b>Exchange Management Tools</b>](https://learn.microsoft.com/en-us/exchange/plan-and-deploy/post-installation-tasks/install-management-tools?view=exchserver-2019)
+ Optionally, connect to your On-Prem Exchange server by `Connect-ExchangeServer -Auto` cmdlet

|No|Function|Description|
|----|----|----|
|1|[<b>Set-PExMaintenanceMode</b>](https://ps1code.com/2024/02/05/pexmm/)|Put an Exchange Server in Maintenance Mode|
|2|[<b>Exit-PExMaintenanceMode</b>](https://ps1code.com/2024/02/05/pexmm/)|Take an Exchange Server out of Maintenance Mode|
|3|[<b>Get-PExMaintenanceMode</b>](https://ps1code.com/2024/02/05/pexmm/)|Verify Exchange Servers Maintenance Mode status|
|4|[<b>Watch-PExMaintenanceMode</b>](https://ps1code.com/)|<b>`New!`</b>Watch all Exchange server maintenance mode components|
|5|[<b>Get-PExServer</b>](https://ps1code.com/2024/02/16/pexsrv/)|Filter Exchange Servers by Release Year|
|6|[<b>Get-PExMailbox</b>](https://ps1code.com/2024/02/22/pexmbx/)|Retrieve mailboxes in Hybrid organization|
|7|[<b>Get-PExMailboxUsage</b>](https://ps1code.com/2024/03/07/pexmsz/)|<b>`New!`</b>Get Exchange mailbox size|
|8|[<b>ConvertFrom-PExExchangeSize</b>](https://ps1code.com/2024/03/07/pexmsz/)|Convert a string, representing a Size, returned by EMS cmdlets|
|9|[<b>New-PercentageBar</b>](https://ps1code.com/2016/07/16/percentage-bar-powershell/)|Create colored and adjustable Percentage Bar|
|10|[<b>Get-PExRecipientType</b>](https://ps1code.com/2024/03/14/pexrcp/)|<b>`New!`</b>Get Recipient type|

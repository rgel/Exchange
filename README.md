# ![ExchangeGithub](https://github.com/rgel/Exchange/assets/6964549/1a0ac5a4-519d-4fe7-8de0-7687e1bd6ce3)$${\color{blue}Exchange \space PowerShell \space Repo}$$

##
### $${\color{green}MODULES}$$

### ${\color{blue}Power-EXCH \space Automation \space Module}$
### Coming soon ...

> [!NOTE]
> EMS is preferred method for connecting Exchange\
> But it is not required, a remote PSSession is enough

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

+ Open <b>EMS</b> [<b>Exchange Management Shell</b>](https://learn.microsoft.com/en-us/powershell/exchange/open-the-exchange-management-shell?view=exchange-ps) console
+ To open <b>EMS</b> on Core Server, type `LaunchEMS` in the console
+ Optionally, connect to your On-Prem Exchange server by `Connect-ExchangeServer -Auto` cmdlet

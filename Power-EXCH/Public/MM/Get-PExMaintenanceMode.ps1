Function Get-PExMaintenanceMode
{
	
<#
.SYNOPSIS
	Get Exchange Server Maintenance Mode.
.DESCRIPTION
	This function checks Exchange Server Maintenance Mode.
.EXAMPLE
	PS C:\> Get-PExMaintenanceMode $env:COMPUTERNAME
.EXAMPLE
	PS C:\> Get-ExchangeServer | Get-PExMaintenanceMode
.EXAMPLE
	PS C:\> Get-MailboxServer | Get-PExMaintenanceMode
.EXAMPLE
	PS C:\> Get-PExServer Ex2016 | Get-PExMaintenanceMode
.NOTES
	Author      :: @ps1code
	Version 1.0 :: 28-Nov-2021  :: [Release] :: Beta
	Version 1.1 :: 28-Dec-2022  :: [Improve] :: New property TotalActiveComponent
	Version 1.2 :: 21-Aug-2024  :: [Improve] :: Added offline check -CoadMonkey
    Version 1.3 :: 10-Aug-2026  :: [Bugfix]  :: Sanitize user input to prevent false data from Get-ServerComponentState
.LINK
	https://ps1code.com/2024/02/05/pexmm/
#>
	
	[CmdletBinding()]
	[Alias('Get-PExMM')]
	Param (
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Exchange server name or object representing Exchange server')]
		[Alias('Name')]
		[string]$Server
	)
	
	Begin
	{
		#$WarningPreference = 'SilentlyContinue'
        $ExchangeServers = (Get-ExchangeServer).name
	}
	Process
	{

        # Querying non-Exchange AD objects returns a deceptive, false-positive array of components.
        If ($Server -notin $ExchangeServers) {Throw "$Server is not a valid Exchange Server."}

		If (Test-Connection -Count 1 -Quiet $Server) {
            $State = if ($ComponentList = (Get-ServerComponentState $Server -ErrorAction Stop | Select-Object Component, State).Where{
				    @('Monitoring', 'RecoveryActionsEnabled') -notcontains $_.Component -and $_.State -eq 'Active'
			    } | Sort-Object Component)
		    {
			    $ActiveComponent = $ComponentList.Component
			    'Connected'
		    }
		    else
		    {
			    $ActiveComponent = $null
			    'Maintenance'
		    }
		
		    [pscustomobject]@{
			    Server = $Server
			    State = [ExchangeServerState]$State
			    ActiveComponentList = $ActiveComponent
			    TotalActiveComponent = $ActiveComponent.Count
		    }
        } Else {
            Write-Verbose "[$Server] is offline." -Verbose:$true
        }
	}
	End { }	
}

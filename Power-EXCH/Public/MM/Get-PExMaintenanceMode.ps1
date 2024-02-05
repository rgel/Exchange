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
		$WarningPreference = 'SilentlyContinue'
	}
	Process
	{
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
	}
	End { }	
}

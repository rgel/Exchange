Function Get-PExMailbox
{
	
<#
.SYNOPSIS
	Get mailbox within Hybrid organization.
.DESCRIPTION
	This function retrieves mailbox no matter where is it located either OnPrem or EXO.
.EXAMPLE
	PS C:\> Get-PExMailbox alias
.EXAMPLE
	PS C:\> 'alias1','alias2' | Get-PExMailbox -CustomObject
.EXAMPLE
	PS C:\> Get-ADUser -Filter {Name -like 'user*'} | Get-PExMailbox -CustomObject -Verbose
.EXAMPLE
	PS C:\> Get-ADGroupMember HR | Get-PExMailbox -CustomObject | Format-Table -AutoSize
.NOTES
	Author      :: @ps1code
	Dependency  :: EMS cmdlets :: Get-Mailbox, Get-RemoteMailbox
	Version 1.0 :: 14-Dec-2022 :: [Release] :: Beta
	Version 1.1 :: 24-Oct-2023 :: [Change]  :: New parameter -CustomObject, the verbose output improved
	Version 1.2 :: 06-Dec-2023 :: [Bugfix]  :: Disconnect from EXO if connected, the Get-RemoteMailbox cmdlet is available in OnPrem only
	Version 1.3 :: 28-Jan-2024 :: [Bugfix]  :: Reconnect to OnPrem Exchange after disconnecting from Exchange Online
	Version 1.4 :: 19-Feb-2024 :: [Bugfix]  :: Custom object aligned for both mailbox types
.LINK
	https://ps1code.com/2024/02/22/pexmbx/
#>
	
	[CmdletBinding(ConfirmImpact = 'None')]
	[Alias('pexmbx')]
	Param (
		[Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Specifies any value that uniquely identifies the mailbox')]
		[Alias('Name')]
		$Identity
		 ,
		[Parameter(HelpMessage = 'If specified, returns custom object instead of original one')]
		[switch]$CustomObject
	)
	
	Begin
	{
		if (Get-Command Disconnect-ExchangeOnline -ErrorAction SilentlyContinue)
		{
			Disconnect-ExchangeOnline -Confirm:$false -WarningAction SilentlyContinue
			if (Get-Command Connect-ExchangeServer -ErrorAction SilentlyContinue) { Connect-ExchangeServer -Auto }
		}
	}
	Process
	{
		$Identity = if ($Identity -isnot [string]) { $Identity.ToString() } else { $Identity }
		
		$mbx = try { Get-Mailbox -Identity $Identity -ErrorAction Stop }
		catch { Get-RemoteMailbox -Identity $Identity -ErrorAction SilentlyContinue }
		
		if ($mbx)
		{
			switch ($mbx.RecipientTypeDetails)
			{
				'UserMailbox'
				{
					$Desc = "OnPrem/$($mbx.ServerName):$($mbx.Database)"
					Write-Verbose "$(Get-Date -Format $Format) $($MyInvocation.MyCommand.Name) The [$($Identity):$($mbx.PrimarySmtpAddress)] is [$($Desc)] mailbox"
				}
				'RemoteUserMailbox'
				{
					$Desc = "Office 365/$($mbx.RemoteRecipientType)"
					Write-Verbose "$(Get-Date -Format $Format) $($MyInvocation.MyCommand.Name) The [$($Identity):$($mbx.PrimarySmtpAddress)] is [$($Desc)] mailbox"
				}
				default
				{
					$Desc = "$($_)"
					Write-Verbose "$(Get-Date -Format $Format) $($MyInvocation.MyCommand.Name) The [$($Identity):$($mbx.PrimarySmtpAddress)] is [$_] mailbox"
				}
			}
			
			if ($CustomObject) { $mbx | Select-Object 'Alias', 'PrimarySmtpAddress', 'ProhibitSendQuota', 'WhenMailboxCreated', @{ N = 'Type'; E = { $Desc } } }
			else { $mbx }
		}
		else
		{
			Write-Verbose "$(Get-Date -Format $Format) $($MyInvocation.MyCommand.Name) The [$Identity] mailbox not found"
		}
	}
	End { }	
}

Function Get-PExMailboxUsage
{
	
<#
.SYNOPSIS
	Get mailbox usage.
.DESCRIPTION
	This function retrieves on-premises mailbox usage metrics.
.EXAMPLE
	PS C:\> Get-PExMailboxUsage $Name
.EXAMPLE
	PS C:\> Get-Mailbox $Name | Get-PExMailboxUsage
.EXAMPLE
	PS C:\> Get-ADUser $Name | Get-PExMailboxUsage -Draw
.EXAMPLE
	PS C:\> Get-ADGroupMember $ADGroup | Get-PExMailboxUsage -UtilizationExceed 90
.EXAMPLE
	PS C:\> Get-ADGroupMember $ADGroup | Get-PExMailboxUsage -Verbose | Out-GridView -Title "Mailbox usage report"
.EXAMPLE
	PS C:\> Get-ADGroupMember $ADGroup | Get-PExMailboxUsage -Draw
.NOTES
	Author      :: @ps1code
	Dependency  :: Function     :: New-PercentageBar, ConvertFrom-PExExchangeSize
	Version 1.0 :: 26-Feb-2024  :: [Release] :: Beta
.LINK
	https://ps1code.com/2024/03/07/pexmsz/
#>
	
	[CmdletBinding(ConfirmImpact = 'None', DefaultParameterSetName = 'OBJ')]
	[Alias('Get-PExMailboxSize', 'mbxuse')]
	Param (
		[Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName,
				   HelpMessage = 'Specifies any value that uniquely identifies the mailbox')]
		[string]$Name
		 ,
		[Parameter(Mandatory, ParameterSetName = 'SHOW')]
		[switch]$Draw
		 ,
		[Parameter(ParameterSetName = 'OBJ',
				   HelpMessage = 'If specified, return only mailboxes exceeding this utilization percent')]
		[ValidateRange(1, 100)]
		[uint16]$UtilizationExceed
	)
	
	Begin
	{
		$WarningPreference = 'SilentlyContinue'
		$rgxNotAllowed = '[^\x00-\x7F]|\s'
	}
	Process
	{
		### Is Mailbox exists ? ###
		$ClearName = $Name -replace $rgxNotAllowed, $null
		try { $mb = Get-Mailbox $ClearName -ErrorAction Stop }
		catch { Write-Verbose "SKIPPED :: [$($ClearName)] - on-premises mailbox doesn't exist" }
		
		if ($mb)
		{
			### Calculate actual Mailbox size ###
			if ($mbStats = Get-MailboxStatistics -Identity $mb.Alias -WarningAction SilentlyContinue)
			{
				$GB = ($Size = ConvertFrom-PExExchangeSize -Size $mbStats.TotalItemSize.Value.ToString()).GB
				
				### Get mailbox quota ###
				$CurrentQuotaGB = if (!($CurrentMbxQuotaGB = (ConvertFrom-PExExchangeSize $mb.ProhibitSendReceiveQuota).GB))
				{
					if ($mb.UseDatabaseQuotaDefaults)
					{
						$CurrentDbQuotaGB = (ConvertFrom-PExExchangeSize (Get-MailboxDatabase $mb.Database).ProhibitSendReceiveQuota).GB
						$CurrentDbQuotaGB, 0 | Sort-Object | Select-Object -Last 1
					}
				}
				else
				{
					$CurrentMbxQuotaGB
				}
				
				### Calculate utilization ###
				$UtilizationPcnt = if ($CurrentQuotaGB)
				{
					if (($Trancated = [math]::Truncate($GB * 100 / $CurrentQuotaGB)) -lt 100) { $Trancated + 1 } else { $Trancated }
				}
				else { 0 }
				
				### Return/Out ###
				if ($PSCmdlet.ParameterSetName -eq 'SHOW')
				{
					"$(New-PercentageBar -Percent $UtilizationPcnt -DrawBar) $($mb.PrimarySmtpAddress) [$($Size)/$($CurrentQuotaGB) GB]"
				}
				else
				{
					$return = [PExMailboxUsage] @{
						Alias = $mb.Alias
						Address = $mb.PrimarySmtpAddress
						Size = $Size.ToString()
						SizeGB = $GB
						Quota = "$($CurrentQuotaGB) GB" -replace '^\sGB', 'Unlimited'
						QuotaGB = $CurrentQuotaGB
						UtilizationPercent = $UtilizationPcnt
						UtilizationBar = $(New-PercentageBar -Percent $UtilizationPcnt)
					}
					if ($PSBoundParameters.ContainsKey('UtilizationExceed')) { if ($UtilizationPcnt -ge $UtilizationExceed) { $return } }
					else { $return }
				}
			}
			else { Write-Verbose "SKIPPED :: [$($ClearName)] - user hasn't logged on to mailbox" }
		}
		$mb = $null
	}
	End { }
}

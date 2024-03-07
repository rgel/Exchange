Function ConvertFrom-PExExchangeSize
{
	
<#
.SYNOPSIS
	Convert a string, representing a Size, returned by EMS cmdlets.
.DESCRIPTION
	This function converts string, representing a Size, returned by Exchange Management Shell cmdlets to convenient object.
.EXAMPLE
	PS C:\> ConvertFrom-PExExchangeSize '448.7 GB (481,789,280,256 bytes)'
.EXAMPLE
	PS C:\> Get-MailboxServer |% { Get-MailboxDatabase -Server $_.Name -Status | Select-Object Name, DatabaseSize, @{ N = 'Size'; E = { "$(ConvertFrom-PExExchangeSize $_.DatabaseSize)" } } }
	Add calculated property Size to the Mailbox Database objects.
.EXAMPLE
	PS C:\> Get-MailboxServer |% { Get-MailboxDatabase -Server $_.Name -Status | Select-Object Name, DatabaseSize, @{ N = 'SizeGB'; E = { (ConvertFrom-PExExchangeSize $_.DatabaseSize).GB } } }
	Add calculated property SizeGB to the Mailbox Database objects.
.EXAMPLE
	PS C:\> Get-MailboxServer |% { Get-MailboxDatabase -Server $_.Name -Status | Select-Object Name, DatabaseSize, @{ N = 'SizeGB'; E = { (ConvertFrom-PExExchangeSize $_.DatabaseSize).GB } } } | Where-Object { $_.SizeGB -gt 500 } | Sort-Object SizeGB -Descending
	Filter and sort mailbox databases by their size.
.NOTES
	Author      :: @ps1code
	Version 1.0 :: 23-Nov-2021  :: [Release] :: Beta
	Version 1.1 :: 08-Mar-2022  :: [Bugfix]  :: Empty or zero value for the -Size parameter
	Version 1.2 :: 08-Jan-2023  :: [Bugfix]  :: The 'Bytes' value changed from [string] to [int64] for correct comparison
	Version 1.3 :: 26-Feb-2024  :: [Improve] :: Returned object type changed from generic [pscustomobject] to custom defined [PExSize] type
.OUTPUTS
	[PExSize] Common Exchange object size
.LINK
	https://ps1code.com/2024/03/07/pexmsz/
#>
	
	Param (
		[Parameter(Position = 0)]
		[string]$Size
	)
	
	if ($null, 0, [string]::Empty -notcontains $Size)
	{
		$split = $Size -split '\s\('
		$Text = $split[0]
		$bytes = $split[1] -replace '[\s\),bytes]', $null
		$KB = $bytes/1024
		$MB = $KB/1024
		$GB = $MB/1024
		$TB = $GB/1024
		
		[PExSize] @{
			Optimal = $Text
			Bytes = [int64]$bytes
			KB = [math]::Round($KB, 3)
			MB = [math]::Round($MB, 2)
			GB = [math]::Round($GB, 1)
			TB = [math]::Round($TB, 2)
		}
	}
	else
	{
		[PExSize] @{
			Optimal = '0 Bytes'
			Bytes = [int64]0
			KB = 0
			MB = 0
			GB = 0
			TB = 0
		}
	}
}

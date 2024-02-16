Enum ExRelease {
	Ex2010 = 2010
	Ex2013 = 2013
	Ex2016 = 2016
	Ex2019 = 2019
}

Function Get-PExServer
{
	
<#
.SYNOPSIS
	Get Exchange servers by release.
.DESCRIPTION
	This function filters Exchange servers out by year released.
.EXAMPLE
	PS C:\> Get-PExServer -Version Ex2016
.EXAMPLE
	PS C:\> Get-PExServer 2013 -NameOnly
.EXAMPLE
	PS C:\> Get-PExServer 2019 -Not
	Get all Exchange servers except of 2019 release.
.NOTES
	Author          :: @ps1code
	Version 1.0     :: 30-Jan-2024 :: [Release] :: Beta
.LINK
	https://ps1code.com/2024/02/16/pexsrv/
#>
	
	Param (
		[Parameter(Position = 0, HelpMessage = 'Specifies Exchange server release')]
		[ValidateSet("Ex2010", "Ex2013", "Ex2016", "Ex2019")]
		[ExRelease]$Version = 'Ex2019'
		 ,
		[Parameter(HelpMessage = 'If specified, returns logical -Not results')]
		[switch]$Not
		 ,
		[Parameter(HelpMessage = 'If specified, returns server names only')]
		[switch]$NameOnly
	)
	
	$WarningPreference = 'SilentlyContinue'
	$hashDic = @{
		[ExRelease]::Ex2010 = '14.';
		[ExRelease]::Ex2013 = '15.0';
		[ExRelease]::Ex2016 = '15.1';
		[ExRelease]::Ex2019 = '15.2';
	}
	
	$Target, $Filtered = (Get-ExchangeServer).Where({ $_.AdminDisplayVersion -match "\s$([regex]::Escape($hashDic.$Version))" }, 'Split')
	
	$Return = if ($Not) { $Filtered } else { $Target }
	
	if ($NameOnly) { $Return.Name } else { $Return }	
}

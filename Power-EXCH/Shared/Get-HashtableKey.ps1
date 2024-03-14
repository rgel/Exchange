Function Get-HashtableKey
{
	
<#
.SYNOPSIS
	Return hashtable Key(s) by their Value.
.EXAMPLE
	PS C:\> Get-HashtableKey -Hashtable @{ 'One' = 1; 'Two' = 2; 'Three' = 3; 'Four' = 4; 'Five' = 5; 'Six' = 6; 'Seven' = 7; 'Eight' = 8; 'Nine' = 9; 'Zero' = 0;} -Value 0
	Simple dictionary to translate digits to their literal names.
.EXAMPLE
	PS C:\> (Get-HashtableKey @{ 'One' = 1; 'Two' = 2; 'Three' = 3; 'Four' = 4; 'Five' = 5; 'Six' = 6; 'Seven' = 7; 'Eight' = 8; 'Nine' = 9; 'Zero' = 0;} 8).ToLower()
	If Key is a string there are ToLower() and ToUpper() methods to lower/upper case it.
.EXAMPLE
	PS C:\> Get-HashtableKey @{ 'Good' = 1; 'Bad' = 0; 'Not bad' = 1;} 1
	Multiple keys are returned for duplicate Values.
.NOTES
	Author      :: @ps1code
	Version 1.0 :: 09-Aug-2023 :: [Release] :: Beta
#>
	
	Param (
		[Parameter(Mandatory, Position = 0)]
		[hashtable]$Hashtable
		 ,
		[Parameter(Mandatory, Position = 1)]
		$Value
	)
	
	if ($Hashtable.ContainsValue($Value)) { $Hashtable.Keys.GetEnumerator() | Where-Object { $Hashtable[$_] -eq $Value } }
}

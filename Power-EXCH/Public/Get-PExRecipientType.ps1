Enum RecipientFilter {
	RemoteOnly
	OnPremOnly
	MailEnabled
	NoMailbox
}

Function Get-PExRecipientType
{
	
<#
.SYNOPSIS
	Get mail recipient type.
.DESCRIPTION
	This function determines mail recipient type with no Exchange OnPrem or EXO connection.
.EXAMPLE
	PS C:\> Get-ADUser $Name | Get-PExRecipientType
.EXAMPLE
	PS C:\> Get-ADUser $env:USERNAME | Get-PExRecipientType | Format-List
.EXAMPLE
	PS C:\> Get-ADUser -LDAPFilter "(&(objectCategory=person)(objectClass=user)(!userAccountControl:1.2.840.113556.1.4.803:=2))" | Get-PExRecipientType
.EXAMPLE
	PS C:\> Get-ADGroupMember $ADGroup | Get-ADUser | Get-PExRecipientType | Out-GridView -Title 'Recipients report'
.EXAMPLE
	PS C:\> Get-ADGroupMember $ADGroup | Get-ADUser | Get-PExRecipientType -Filter MailEnabled
	Builtin filtering.
.EXAMPLE
	PS C:\> Get-ADGroupMember $ADGroup | Get-ADUser | Get-PExRecipientType NoMailbox
.EXAMPLE
	PS C:\> Get-ADGroupMember $ADGroup | Get-ADUser | Get-PExRecipientType | Where-Object { $_.RecipientDetails -match 'shared' }
	Custom filtering.
.NOTES
	Author      :: @ps1code
	Dependency  :: PS Module   :: ActiveDirectory Module (part of RSAT)
	Dependency  :: Function    :: Get-HashtableKey (part of this module)
	Version 1.0 :: 09-Aug-2023 :: [Release] :: Beta
	Version 1.1 :: 10-Mar-2024 :: [Improve] :: New parameter -Filter
.LINK
	https://ps1code.com/2024/03/14/pexrcp/
#>
	
	[CmdletBinding(ConfirmImpact = 'None')]
	[Alias('Get-RecipientType')]
	Param (
		[Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'Specifies Active Directory user account object(s), returned by Get-ADUser cmdlet')]
		[Alias("SamAccountName")]
		[Microsoft.ActiveDirectory.Management.ADUser]$User
		 ,
		[Parameter(Position = 0, HelpMessage = 'If specified, only certain type of recipients will be returned')]
		[RecipientFilter]$Filter
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		$WarningPreference = 'SilentlyContinue'
		
		### msExchRecipientDisplayType ###
		$htRecipientType = @{
			'MailUser (RemoteUserMailbox)' = -2147483642;
			'MailUser (RemoteRoomMailbox)' = -2147481850;
			'MailUser (RemoteEquipmentMailbox)' = -2147481594;
			'ACLable Remote Mailbox User' = -1073741818;
			'UserMailbox (Shared)' = 0;
			'MailUniversalDistributionGroup' = [int64]'1';
			'MailContact' = [int64]'6';
			'UserMailbox (Room)' = [int64]'7';
			'UserMailbox (Equipment)' = [int64]'8';
			'UserMailbox' = 1073741824;
			'MailUniversalSecurityGroup' = 1073741833;
			'User (NoMailbox)' = 999999;
		}
		
		### msExchRecipientTypeDetails ###
		$htRecipientTypeDetails = @{
			'UserMailbox' = [int64]'1';
			'LinkedMailbox' = [int64]'2';
			'LinkedRoomMailbox' = 2199023255552;
			'SharedMailbox' = [int64]'4';
			'RoomMailbox' = [int64]'16';
			'EquipmentMailbox' = [int64]'32';
			'MailUser' = [int64]'128';
			'RemoteUserMailbox' = 2147483648;
			'RemoteRoomMailbox' = 8589934592;
			'RemoteEquipmentMailbox' = 17179869184;
			'RemoteSharedMailbox' = 34359738368;
			'User' = 999999;
		}
		
		### msExchRemoteRecipientType ###
		$htRemoteRecipientType = @{
			'ProvisionMailbox' = [int64]'1';
			'ProvisionArchive (On-Prem Mailbox)' = [int64]'2';
			'ProvisionMailbox, ProvisionArchive' = [int64]'3';
			'Migrated (UserMailbox)' = [int64]'4';
			'ProvisionArchive, Migrated' = [int64]'6';
			'DeprovisionMailbox' = [int64]'8';
			'ProvisionArchive, DeprovisionMailbox' = [int64]'10';
			'DeprovisionArchive (On-Prem Mailbox)' = [int64]'16';
			'ProvisionMailbox, DeprovisionArchive' = [int64]'17';
			'Migrated, DeprovisionArchive' = [int64]'20';
			'DeprovisionMailbox, DeprovisionArchive' = [int64]'24';
			'ProvisionMailbox, RoomMailbox' = [int64]'33';
			'ProvisionMailbox, ProvisionArchive, RoomMailbox' = [int64]'35';
			'Migrated, RoomMailbox' = [int64]'36';
			'ProvisionArchive, Migrated, RoomMailbox' = [int64]'38';
			'ProvisionMailbox, DeprovisionArchive, RoomMailbox' = [int64]'49';
			'Migrated, DeprovisionArchive, RoomMailbox' = [int64]'52';
			'ProvisionMailbox, EquipmentMailbox' = [int64]'65';
			'ProvisionMailbox, ProvisionArchive, EquipmentMailbox' = [int64]'67';
			'Migrated, EquipmentMailbox' = [int64]'68';
			'ProvisionArchive, Migrated, EquipmentMailbox' = [int64]'70';
			'ProvisionMailbox, DeprovisionArchive, EquipmentMailbox' = [int64]'81';
			'Migrated, DeprovisionArchive, EquipmentMailbox' = [int64]'84';
			'ProvisionMailbox, SharedMailbox' = [int64]'97';
			'ProvisionMailbox, ProvisionArchive, SharedMailbox' = [int64]'99';
			'Migrated, SharedMailbox' = [int64]'100';
			'ProvisionArchive, Migrated, SharedMailbox' = [int64]'102';
			'Migrated, DeprovisionArchive, SharedMailbox' = [int64]'116';
		}
	}
	Process
	{
		$msExch = Get-ADUser $User.DistinguishedName -Properties * | Select-Object msExch*, SamAccountName, mail
		
		$rdt = if ($msExch | Get-Member msExchRecipientDisplayType) { $msExch.msExchRecipientDisplayType } else { 999999 }
		$rtd = if ($msExch | Get-Member msExchRecipientTypeDetails) { $msExch.msExchRecipientTypeDetails } else { 999999 }
		$RemoteType = if ($msExch | Get-Member msExchRemoteRecipientType)
		{
			$rrt = $msExch.msExchRemoteRecipientType
			Write-Debug "$($rdt)|$($rtd)|$($rrt)"
			Get-HashtableKey $htRemoteRecipientType $rrt
		}
		else
		{
			Write-Debug "$($rdt)|$($rtd)"
			'OnPrem'
		}
		
		$Rcpt = [PExRecipient] @{
			'User' = $msExch.SamAccountName
			'MailAddress' = $msExch.mail
			'RecipientType' = Get-HashtableKey $htRecipientType $rdt
			'RecipientDetails' = Get-HashtableKey $htRecipientTypeDetails $rtd
			'RemoteType' = $RemoteType
		}
		
		if ($PSBoundParameters.ContainsKey('Filter'))
		{
			switch ($Filter)
			{
				'RemoteOnly'
				{
					if ($Rcpt.IsRemote()) { $Rcpt }
				}
				'OnPremOnly'
				{
					if (!$Rcpt.IsRemote()) { $Rcpt }
				}
				'MailEnabled'
				{
					if ($Rcpt.IsMailEnabled()) { $Rcpt }
				}
				'NoMailbox'
				{
					if (!$Rcpt.IsMailEnabled()) { $Rcpt }
				}
			}
		}
		else
		{
			$Rcpt
		}
	}
	End { }
}

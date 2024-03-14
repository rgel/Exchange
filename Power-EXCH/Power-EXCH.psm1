#region Enum

### Global Enum | Usage :: Get-PExMaintenanceMode | [System.Enum]::GetNames([ExchangeServerState]) ###
Add-Type -TypeDefinition @"
   public enum ExchangeServerState
   {
    Connected,
	Maintenance
   }
"@

### Global Enum | Usage :: Test-PExVD | [System.Enum]::GetNames([ExchangeServerHealthCheckServiceUrl]) ###
Add-Type -TypeDefinition @"
   public enum ExchangeServerHealthCheckServiceUrl
   {
    RPC,
	OWA,
	EWS,
	Autodiscover,
	OAB,
	MAPI,
	ECP
   }
"@

### Global Enum | Usage :: Get-PExAlarm | [System.Enum]::GetNames([ExchangeServerAlarm]) ###
Add-Type -TypeDefinition @"
   public enum ExchangeServerAlarm
   {
    Queue,
	DBCopy,
	Disk
   }
"@

### Global Enum | Usage :: Get-PExAlarm | [System.Enum]::GetNames([ExchangeOrgAlarm]) ###
Add-Type -TypeDefinition @"
   public enum ExchangeOrgAlarm
   {
    DAG
   }
"@

### Global Enum | Usage :: Update-PExMailboxQuota | [System.Enum]::GetNames([ExchangeQuotaTier]) ###
Add-Type -TypeDefinition @"
   public enum ExchangeQuotaTier
   {
    Basic,
	Advanced,
	Premium,
	VIP,
	O365,
	UNLIMITED
   }
"@

### Global Enum | Usage :: Get-PExPFPermission | [System.Enum]::GetNames([ExchangePFAccessRight]) ###
Add-Type -TypeDefinition @"
   public enum ExchangePFAccessRight
   {
	Owner,    
	PublishingEditor,
	Editor,
	PublishingAuthor,
	Author,
	NonEditingAuthor,
	Reviewer,
	Contributor,
	None,
	FolderVisible
	}
"@

#endregion

#region Global:

### TIER MATRIX ###
$global:Tier = @{
	'Tier1' = @{
		'Name' = [ExchangeQuotaTier]::Basic;
		'Quota' = 3;
		'Count' = 4800;
		'Color' = [System.ConsoleColor]::Green;
		'ArchiveQuota' = 5;
		'ArchiveWarningQuota' = 4.5;
	};
	'Tier2' = @{
		'Name' = [ExchangeQuotaTier]::Advanced;
		'Quota' = 15;
		'Count' = 150;
		'Color' = [System.ConsoleColor]::Yellow;
		'ArchiveQuota' = 10;
		'ArchiveWarningQuota' = 9;
	};
	'Tier3' = @{
		'Name' = [ExchangeQuotaTier]::Premium;
		'Quota' = 25;
		'Count' = 40;
		'Color' = [System.ConsoleColor]::Cyan;
		'ArchiveQuota' = 15;
		'ArchiveWarningQuota' = 14;
	};
	'Tier4' = @{
		'Name' = [ExchangeQuotaTier]::VIP;
		'Quota' = 50;
		'Count' = 10;
		'Color' = [System.ConsoleColor]::DarkRed;
		'ArchiveQuota' = 50;
		'ArchiveWarningQuota' = 48;
	};
	'Tier5' = @{
		'Name' = [ExchangeQuotaTier]::O365;
		'Quota' = 99;
		'Count' = 5;
		'Color' = [System.ConsoleColor]::DarkBlue;
		'ArchiveQuota' = 100;
		'ArchiveWarningQuota' = 98;
	};
	'Unlimited' = @{
		'Name' = [ExchangeQuotaTier]::UNLIMITED;
		'Quota' = 'Unlimited';
		'Count' = 5;
		'Color' = [System.ConsoleColor]::Red;
		'ArchiveQuota' = 'Unlimited';
	};
}
### DB INHERITED QUOTA ###
$global:Inherited = @{
	'UseDatabaseQuotaDefaults' = $true;
}
### TIER #1 ###
$global:Tier1 = @{
	'IssueWarningQuota' = '2.75GB';
	'ProhibitSendQuota' = '2.8GB';
	'ProhibitSendReceiveQuota' = "$($Tier.Tier1.Quota)GB";
	'UseDatabaseQuotaDefaults' = $false;
}
$global:ArchiveTier1 = @{
	'ArchiveQuota' = "$($Tier.Tier1.ArchiveQuota)GB";
	'ArchiveWarningQuota' = "$($Tier.Tier1.ArchiveWarningQuota)GB";
}
### TIER #2 ###
$global:Tier2 = @{
	'IssueWarningQuota' = '14.0GB';
	'ProhibitSendQuota' = '14.5GB';
	'ProhibitSendReceiveQuota' = "$($Tier.Tier2.Quota)GB";
	'UseDatabaseQuotaDefaults' = $false;
}
$global:ArchiveTier2 = @{
	'ArchiveQuota' = "$($Tier.Tier2.ArchiveQuota)GB";
	'ArchiveWarningQuota' = "$($Tier.Tier2.ArchiveWarningQuota)GB";
}
### TIER #3 ###
$global:Tier3 = @{
	'IssueWarningQuota' = '24.0GB';
	'ProhibitSendQuota' = '24.5GB';
	'ProhibitSendReceiveQuota' = "$($Tier.Tier3.Quota)GB";
	'UseDatabaseQuotaDefaults' = $false;
}
$global:ArchiveTier3 = @{
	'ArchiveQuota' = "$($Tier.Tier3.ArchiveQuota)GB";
	'ArchiveWarningQuota' = "$($Tier.Tier3.ArchiveWarningQuota)GB";
}
### TIER #4 ###
$global:Tier4 = @{
	'IssueWarningQuota' = '49GB';
	'ProhibitSendQuota' = '49.5GB';
	'ProhibitSendReceiveQuota' = "$($Tier.Tier4.Quota)GB";
	'UseDatabaseQuotaDefaults' = $false;
}
$global:ArchiveTier4 = @{
	'ArchiveQuota' = "$($Tier.Tier4.ArchiveQuota)GB";
	'ArchiveWarningQuota' = "$($Tier.Tier4.ArchiveWarningQuota)GB";
}
### TIER #5 ###
$global:Tier5 = @{
	'IssueWarningQuota' = '97GB';
	'ProhibitSendQuota' = '98.5GB';
	'ProhibitSendReceiveQuota' = "$($Tier.Tier5.Quota)GB";
	'UseDatabaseQuotaDefaults' = $false;
}
$global:ArchiveTier5 = @{
	'ArchiveQuota' = "$($Tier.Tier5.ArchiveQuota)GB";
	'ArchiveWarningQuota' = "$($Tier.Tier5.ArchiveWarningQuota)GB";
}
### UNLIMITED MAILBOX ###
$global:Unlimited = @{
	'IssueWarningQuota' = 'Unlimited';
	'ProhibitSendQuota' = 'Unlimited';
	'ProhibitSendReceiveQuota' = 'Unlimited';
	'UseDatabaseQuotaDefaults' = $false;
}
### UNLIMITED ARCHIVE ###
$global:UnlimitedArchive = @{
	'ArchiveQuota' = 'Unlimited';
	'UseDatabaseQuotaDefaults' = $false;
}
### MANDATORY SERVICES ###
$global:ExchServiceSnapshot = @{
	'MSExchangeADTopology' = 'Microsoft Exchange Active Directory Topology';
	'MSExchangeAntispamUpdate' = 'Microsoft Exchange Anti-spam Update';
	'MSExchangeCompliance' = 'Microsoft Exchange Compliance Service';
	'MSExchangeDagMgmt' = 'Microsoft Exchange DAG Management';
	'MSExchangeDelivery' = 'Microsoft Exchange Mailbox Transport Delivery';
	'MSExchangeDiagnostics' = 'Microsoft Exchange Diagnostics';
	'MSExchangeEdgeSync' = 'Microsoft Exchange EdgeSync';
	'MSExchangeFastSearch' = 'Microsoft Exchange Search';
	'MSExchangeFrontEndTransport' = 'Microsoft Exchange Frontend Transport';
	'MSExchangeHM' = 'Microsoft Exchange Health Manager';
	'MSExchangeHMRecovery' = 'Microsoft Exchange Health Manager Recovery';
	'MSExchangeIS' = 'Microsoft Exchange Information Store';
	'MSExchangeMailboxAssistants' = 'Microsoft Exchange Mailbox Assistants';
	'MSExchangeMailboxReplication' = 'Microsoft Exchange Mailbox Replication';
	'MSExchangeRepl' = 'Microsoft Exchange Replication';
	'MSExchangeRPC' = 'Microsoft Exchange RPC Client Access';
	'MSExchangeServiceHost' = 'Microsoft Exchange Service Host';
	'MSExchangeSubmission' = 'Microsoft Exchange Mailbox Transport Submission';
	'MSExchangeThrottling' = 'Microsoft Exchange Throttling';
	'MSExchangeTransport' = 'Microsoft Exchange Transport';
	'MSExchangeTransportLogSearch' = 'Microsoft Exchange Transport Log Search';
	'MSExchangeUM' = 'Microsoft Exchange Unified Messaging';
	'MSExchangeUMCR' = 'Microsoft Exchange Unified Messaging Call Router';
	'ClusSvc' = 'Cluster Service';
}
$global:ExchService3dParty = @{
	'Centerity.Agent' = 'Centerity Monitor Agent';						# Monitor
	'GxFWD(Instance001)' = 'Commvault Network Daemon (Instance001)';	# Backup
	'MSME' = 'McAfee Security for Microsoft Exchange';					# AV for Exchange
	'SentinelAgent' = 'Sentinel Agent';									# AV for OS
	'RFExchConn' = 'RightFax Exchange Connector';						# FAX
}

### WELL-KNOWN LOG PATHS ###
$global:ExchLogsPath = @{
	'IISLog' = 'C$\inetpub\logs\LogFiles\';
	'ExchangeLogging' = 'C$\Program Files\Microsoft\Exchange Server\V15\Logging\';
	'EtlTraces' = 'C$\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\ETLTraces\';
	'EtlLogging' = 'C$\Program Files\Microsoft\Exchange Server\V15\Bin\Search\Ceres\Diagnostics\Logs\';
}

$global:SMTPServer = $PSEmailServer

#endregion

#region Local:

$Format = 'M/dd/yyyy h:mm:ss tt'

$ExchActiveComponent = @(
	'ActiveSyncProxy',
	'AutoDiscoverProxy',
	'CafeLAMv2',
	'DefaultProxy',
	'E4EProxy',
	'EcpProxy',
	'EdgeTransport',
	'EwsProxy',
	'FrontendTransport',
	'HighAvailability',
	'HttpProxyAvailabilityGroup',
	'HubTransport',
	'ImapProxy',
	'LogExportProvider',
	'Lsass',
	'MailboxDeliveryProxy',
	'MapiProxy',
	'OabProxy',
	'OwaProxy',
	'PopProxy',
	'PushNotificationsProxy',
	'RestProxy',
	'RoutingService',
	'RoutingUpdates',
	'RpcProxy',
	'RpsProxy',
	'RwsProxy',
	'ServerWideOffline',
	'SharedCache',
	'UMCallRouter',
	'XropProxy'
)

#endregion

#region Classes

Class PEx { }

Class PExSize: PEx
{
	[ValidateNotNullOrEmpty()][string]$Optimal
	[long]$Bytes
	[decimal]$KB
	[double]$MB
	[double]$GB
	[double]$TB
	
	[string] ToString () { return "$($this.Optimal)" }
}

Class PExMailboxUsage: PEx
{
	[ValidateNotNullOrEmpty()][string]$Alias
	[ValidateNotNullOrEmpty()][string]$Address
	[ValidateNotNullOrEmpty()][string]$Size
	[double]$SizeGB
	[ValidateNotNullOrEmpty()][string]$Quota
	[double]$QuotaGB
	[double]$UtilizationPercent
	[ValidateNotNullOrEmpty()][string]$UtilizationBar
	
	[string] ToString () { return "$($this.UtilizationBar) $($this.Address) [$($this.Size)/$($this.Quota)]" }
}

Class PExTier: PEx
{
	[ValidateNotNullOrEmpty()][string]$Tier
	[ValidateNotNullOrEmpty()][string]$Name
	[ValidateNotNullOrEmpty()][string]$Quota
	[ValidateNotNullOrEmpty()][string]$ArchiveQuota
	
	[string] ToString () { return "$($this.Tier)::$($this.Name)" }
}

Class PExRecipient: PEx
{
	[ValidateNotNullOrEmpty()][string]$User
	[string]$MailAddress
	[ValidateNotNullOrEmpty()][string]$RecipientType
	[ValidateNotNullOrEmpty()][string]$RecipientDetails
	[ValidateNotNullOrEmpty()][string]$RemoteType
	
	[string] ToString () { return "$($this.User) [$($this.RemoteType)\$($this.RecipientType)]" }
	[bool] IsRemote () { if ($this.RemoteType -ne 'OnPrem') { return $true } else { return $false } }
	[bool] IsMailEnabled () { if ($this.MailAddress) { return $true } else { return $false } }
}

#endregion

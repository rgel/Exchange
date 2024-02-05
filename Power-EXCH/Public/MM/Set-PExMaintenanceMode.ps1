Function Set-PExMaintenanceMode
{
	
<#
.SYNOPSIS
	Put Exchange Server in Maintenance Mode.
.DESCRIPTION
	This function puts Exchange Server into Maintenance Mode.
.EXAMPLE
	PS C:\> Set-PExMaintenanceMode
.EXAMPLE
	PS C:\> Set-PExMaintenanceMode -Confirm:$false
	Silently put Exchange server into Maintenance Mode, restart server at the end.
.NOTES
	Author      :: @ps1code
	Dependency  :: Function     :: Get-PExMaintenanceMode
	Version 1.0 :: 26-Dec-2021  :: [Release] :: Beta
	Version 1.1 :: 03-Aug-2022  :: [Improve] :: Progress bar and steps counter, Parameter free function
	Version 1.2 :: 19-Apr-2023  :: [Bugfix]  :: Error thrown on empty queue
	Version 1.3 :: 27-Aug-2023  :: [Improve] :: Warn about active mailbox move requests
	Version 1.4 :: 27-Aug-2023  :: [Improve] :: Shutdown option
	Version 1.5 :: 03-Sep-2023  :: [Improve] :: Warn about additional servers in MM
.LINK
	https://ps1code.com/2024/02/05/pexmm/
#>
	
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	[Alias('Enter-PExMaintenanceMode', 'Enable-PExMaintenanceMode', 'Enter-PExMM')]
	Param ()
	
	Begin
	{
		$FunctionName = '{0}' -f $MyInvocation.MyCommand
		Write-Verbose "$FunctionName :: Started at [$(Get-Date)]" -Verbose:$true
		$Server = $($env:COMPUTERNAME)
		$i = 0
		$TotalStep = 6
		$WarningPreference = 'SilentlyContinue'
		$Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
		$Fqdn = ([System.Net.Dns]::GetHostByName($env:COMPUTERNAME)).HostName
	}
	Process
	{
		### Warn about in-progress mailbox migrations ###
		if ($InProgressReq = Get-MoveRequest | Get-MoveRequestStatistics | Where-Object { $_.Status.Value -eq 'InProgress' -and $_.SourceServer, $_.TargetServer -contains $Fqdn })
		{
			$CountReq = ($InProgressReq | Measure-Object -Line -Property DisplayName).Lines
			$InProgressReq | Out-Host
			Write-Warning "The [$Server] is participating in $($CountReq) ACTIVE mailbox migration jobs !!!" -Verbose:$true
		}
		
		### Warn about another servers in MM ###
		if ($CurrentMM = Get-ClusterNode | Where-Object { $_.State -ne 'Up' })
		{
			$MMCount = ($CurrentMM | Measure-Object -Property Name -Line).Lines
			if ($MMCount -eq 1) { Write-Warning "There is additional server in the Maintenance Mode" -Verbose:$true }
			else { Write-Warning "There are additional $($MMCount) servers in the Maintenance Mode" -Verbose:$true }
		}
		
		### Set the Hub Transport service to draining. It will stop accepting any more messages ###
		$i++
		if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Set the Hub Transport service to draining"))
		{
			Write-Progress -Activity "$($FunctionName)" `
						   -Status "Exchange server: $($Server)" `
						   -CurrentOperation "Current operation: [Step $i of $TotalStep] Set the Hub Transport service to draining" `
						   -PercentComplete ($i/$($TotalStep) * 100) -Id 0
			Set-ServerComponentState -Identity $Server -Component HubTransport -State Draining -Requester Maintenance -Confirm:$false
		}
		
		### Redirect any queued messages to another DAG members ###
		$i++
		$TargetHostname = Get-ClusterNode | Where-Object { $_.Name -ne $Server -and $_.State -eq 'Up' } | Sort-Object { Get-Random } | Select-Object -First 1
		$TargetFqdn = "$($TargetHostname).$($Domain)"
		
		$ServerStatus = Get-PExMaintenanceMode -Server $Server
		$TargetServerStatus = Get-PExMaintenanceMode -Server $TargetHostname
		if (@($ServerStatus.State, $TargetServerStatus.State) -notcontains 'Maintenance')
		{
			if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Redirect messages queue to [$($TargetFqdn)]"))
			{
				Write-Progress -Activity "$($FunctionName)" `
							   -Status "Exchange server: $($Server)" `
							   -CurrentOperation "Current operation: [Step $i of $TotalStep] Redirect messages queue to [$($TargetFqdn)]" `
							   -PercentComplete ($i/$($TotalStep) * 100) -Id 0
				### Save transport queue stats before redirecting messages ###
				$QueueLength = (Get-Queue -Server $Server | Measure-Object -Property MessageCount -Sum).Sum
				
				Redirect-Message -Server $Server -Target $TargetFqdn -Confirm:$false
				
				if ($QueueLength)
				{
					### Wait the transport queue would be empty or almost empty ###
					Write-Verbose "Waiting for the transport queue would be almost empty ..." -Verbose:$true
					do
					{
						$Queue = Get-Queue -Server $Server -ErrorAction SilentlyContinue
						$Queue | Select-Object Identity, DeliveryType, Status, MessageCount
						$QueueLengthNow = ($Queue | Measure-Object -Property MessageCount -Sum).Sum
						$QueuePercent = if ($QueueLength -eq 0) { 1 }
						else { $($QueueLength - $QueueLengthNow)/$($QueueLength) }
						Write-Progress -Activity "Waiting for [Step $i]" `
									   -Status "Moving $($QueueLengthNow) queued messages to other transport servers ..." `
									   -CurrentOperation "Currently queued: $($QueueLengthNow) messages" `
									   -PercentComplete ($QueuePercent * 100) -Id 1
						Start-Sleep -Seconds 30
					}
					while ($QueueLengthNow -gt 20)
					Write-Progress -Activity "Completed" -Completed -Id 1
				}
				else
				{
					Write-Verbose "The transport queue is empty" -Verbose:$true
				}
			}
		}
		else
		{
			throw "Either source or target server is already in Maintenance Mode !"
		}
		
		### Suspend Server from the DAG ###
		$i++
		if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Suspend Server from the DAG"))
		{
			Write-Progress -Activity "$($FunctionName)" `
						   -Status "Exchange server: $($Server)" `
						   -CurrentOperation "Current operation: [Step $i of $TotalStep] Suspend Server from the DAG" `
						   -PercentComplete ($i/$($TotalStep) * 100) -Id 0
			Suspend-ClusterNode $Server -Wait -Drain -Confirm:$false | Out-Null
		}
		Get-ClusterNode | Select-Object Name, Cluster, ID, State -Unique | Format-Table -AutoSize
		
		### Disable DB copy automatic activation and move any active DB copies to other DAG members ###
		$i++
		if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Disable DB copy automatic activation & Move any active DB copies to other DAG members"))
		{
			Write-Progress -Activity "$($FunctionName)" `
						   -Status "Exchange server: $($Server)" `
						   -CurrentOperation "Current operation: [Step $i of $TotalStep] Disable DB copy automatic activation & Move any active DB copies to other DAG members" `
						   -PercentComplete ($i/$($TotalStep) * 100) -Id 0
			### Save mounted DB copies stats before moving ###
			$dbMountedCount = (Get-MailboxDatabaseCopyStatus -Server $Server | Where-Object { $_.Status -eq "Mounted" } | Measure-Object -Property Name -Line).Lines
			
			Set-MailboxServer $Server -DatabaseCopyActivationDisabledAndMoveNow:$true -Confirm:$false
			Set-MailboxServer $Server -DatabaseCopyAutoActivationPolicy Blocked -Confirm:$false
			
			### Wait for any database copies that are still mounted on the server ###
			Write-Verbose "Waiting for any database copies that are still mounted on the server ..." -Verbose:$true
			do
			{
				$dbMounted = Get-MailboxDatabaseCopyStatus -Server $Server | Where-Object { $_.Status -eq "Mounted" }
				$dbMounted | Select-Object Name, DatabaseName, Status, CopyQueueLength | Sort-Object DatabaseName
				$dbMounteNow = ($dbMounted | Measure-Object -Property Name -Line).Lines -replace '^$', '0'
				Write-Progress -Activity "Waiting for [Step $i]" `
							   -Status "Moving $($dbMountedCount) DB copies to other DAG members ..." `
							   -CurrentOperation "Currently mounted: $($dbMounteNow) DB copies" `
							   -PercentComplete ($($dbMountedCount - [int]$dbMounteNow)/$($dbMountedCount) * 100) -Id 2
				Start-Sleep -Seconds 30
			}
			while ($dbMounted)
			Write-Progress -Activity "Completed" -Completed -Id 2
		}
		
		### Put the server into Maintenance ###
		$i++
		if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Put the server into Maintenance"))
		{
			Write-Progress -Activity "$($FunctionName)" `
						   -Status "Exchange server: $($Server)" `
						   -CurrentOperation "Current operation: [Step $i of $TotalStep] Put the server into Maintenance" `
						   -PercentComplete ($i/$($TotalStep) * 100) -Id 0
			Set-ServerComponentState $Server -Component ServerWideOffline -State Inactive -Requester Maintenance -Confirm:$false
		}
		
		### Reboot/Shutdown the server ###
		$i++
		$ServerStatusAfter = Get-PExMaintenanceMode -Server $Server
		if ($ServerStatusAfter.State -eq 'Maintenance')
		{
			$ServerStatusAfter
			if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Reboot the server"))
			{
				Write-Progress -Activity "$($FunctionName)" `
							   -Status "Exchange server: $($Server)" `
							   -CurrentOperation "Current operation: [Step $i of $TotalStep] Reboot the server OS" `
							   -PercentComplete ($i/$($TotalStep) * 100) -Id 0
				Restart-Computer -ComputerName $Server -Force -Confirm:$false
			}
			else
			{
				if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Shutdown the server"))
				{
					Write-Progress -Activity "$($FunctionName)" `
								   -Status "Exchange server: $($Server)" `
								   -CurrentOperation "Current operation: [Step $i of $TotalStep] Shutdown the server OS" `
								   -PercentComplete ($i/$($TotalStep) * 100) -Id 0
					Stop-Computer -ComputerName $Server -Force -Confirm:$false
				}
			}
		}
		
		Write-Progress -Activity "Completed" -Completed -Id 0
	}
	End { Write-Verbose "$FunctionName :: Finished at [$(Get-Date)]" -Verbose:$true }	
}
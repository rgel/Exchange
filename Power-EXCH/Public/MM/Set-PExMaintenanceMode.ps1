Function Set-PExMaintenanceMode
{
	
<#
.SYNOPSIS
	Put Exchange Server in Maintenance Mode.
.DESCRIPTION
	This function puts Exchange Server into Maintenance Mode.
.PARAMETER Server
    Exchange server name or object representing Exchange server
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
    Version 1.6 :: 27-Jun-2024  :: [Improve] :: Add ability to run from admin workstation
                                :: [Bugfix]  :: Divide by 0 error if no mounted databases -CoadMonkey
    Version 1.7 :: 5-Jul-2024   :: [Bugfix]  :: Queue redirect not filtering out ShadowRedundancy queues -CoadMonkey
    Version 1.8 :: 21-Aug-2024  :: [Bugfix]  :: Infinite loop and other errors if there are non-DAG databases -CoadMonkey
                                :: [Improve] :: Reroute messages using AD Sites instead of DAG members. Add more messages.
                                                Add more process verifications. -CoadMonkey
    Version 1.9 :: 27-Sep-2024  :: [Bugfix]  :: Divide by 0 error in Write-Progress waiting for DBs to dismount -CoadMonkey
    Version 1.10 :: 27-Jun-2025  :: [Improve]  :: Added pause to confirm reboot / shutdown.


.LINK
	https://ps1code.com/2024/02/05/pexmm/
#>
	
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	[Alias('Enter-PExMaintenanceMode', 'Enable-PExMaintenanceMode', 'Enter-PExMM')]
	Param (
		[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Exchange server name or object representing Exchange server')]
		[Alias('Name')]
		[string]$Server = $($env:COMPUTERNAME)
	)
	
	Begin
	{
        $FunctionName = '{0}' -f $MyInvocation.MyCommand
		Write-Verbose "$FunctionName :: Started at [$(Get-Date)] on $Server" -Verbose:$True
        Write-Verbose "Executing Get-ExchangeServer"
        $ExchangeServers = Get-ExchangeServer
        If ($Server -notin ($ExchangeServers).name) {
            throw "$Server is not an Exchange server. Use -Server to specify a different name."
        }
        $RunLocal = $False
        If ($env:COMPUTERNAME -eq $Server) { $RunLocal = $True }
        $i = 0
        Write-Verbose "Executing Get-MailboxServer"
        $MailboxServer = Get-MailboxServer -Identity $Server
        If ( $MailboxServer.DatabaseAvailabilityGroup -eq $null ) {    # If Server is not a DAG member
            $TotalStep = 5
        } Else {
            $TotalStep = 6
        }        
		$Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
		$Fqdn = ([System.Net.Dns]::GetHostByName($env:COMPUTERNAME)).HostName
	}
	Process
	{

        ### Warn about in-progress mailbox migrations ###
		Write-Verbose "Executing Get-MoveRequestStatistics"
        if ($InProgressReq = Get-MoveRequest | Get-MoveRequestStatistics | Where-Object { $_.Status.Value -eq 'InProgress' -and $_.SourceServer, $_.TargetServer -contains $Fqdn })
		{
			$CountReq = ($InProgressReq | Measure-Object -Line -Property DisplayName).Lines
			$InProgressReq | Out-Host
			Write-Warning "The [$Server] is participating in $($CountReq) ACTIVE mailbox migration jobs !!!" -Verbose:$True
		}
		
		### Warn about another servers in MM ###
        If ( $MailboxServer.DatabaseAvailabilityGroup -ne $null ) {    # Skip if Server is not a DAG member
            Write-Verbose "Executing Get-ClusterNode"
            If ($RunLocal)
            {
                $CurrentMM = Get-ClusterNode | Where-Object { $_.PSComputerName -ne $Server -and $_.State -ne 'Up' }
            }
            Else
            {
                $CurrentMM = Invoke-Command -ComputerName $Server -ScriptBlock {
                    Get-ClusterNode | Where-Object { $_.PSComputerName -ne $Server -and $_.State -ne 'Up' }
                }
            }    
		    if ($CurrentMM)
		    {
			    $MMCount = ($CurrentMM | Measure-Object -Property Name -Line).Lines
			    if ($MMCount -eq 1) { Write-Warning "There is an additional server in Maintenance Mode" -Verbose:$true }
			    else { Write-Warning "There are $($MMCount) additional servers in Maintenance Mode" -Verbose:$true }
		    }
        }	

		### Set the Hub Transport service to draining. It will stop accepting any more messages ###
		$i++
		Write-Progress -Activity "$($FunctionName)" `
						-Status "Exchange server: $($Server)" `
						-CurrentOperation "Current operation: [Step $i of $TotalStep] Set Hub Transport service to draining" `
						-PercentComplete ($i/$($TotalStep) * 100) -Id 0
        Write-Verbose "Executing Get-ServerComponentState"
        $HubTransportState = (Get-ServerComponentState -Identity $Server -Component HubTransport).State
        if ($HubTransportState -notin "Draining","Inactive")
        {

		    if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Set the Hub Transport service to draining"))
		    {
                Write-Verbose "Executing Set-ServerComponentState"			    
                Set-ServerComponentState -Identity $Server -Component HubTransport -State Draining -Requester Maintenance -Confirm:$false
                Write-Verbose "[Step $i of $TotalStep] Hub Transport service set to draining" -Verbose:$True
		    }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Set Hub Transport service to draining Skipped by user"
            }
        }
        Else
        {
            Write-Verbose "[Step $i of $TotalStep] Hub Transport service is already $HubTransportState" -Verbose:$True
        }

		### Redirect any queued messages to another server (try same site first) ###
		$i++
        Write-Progress -Activity "$($FunctionName)" `
			-Status "Exchange server: $($Server)" `
			-CurrentOperation "Current operation: [Step $i of $TotalStep] Redirect messages in queue" `
			-PercentComplete ($i/$($TotalStep) * 100) -Id 0

        # Skip if queue is already empty
        Write-Verbose "Executing Get-Queue"
        if ((Get-Queue -Server $Server | Measure-Object -Property MessageCount -Sum).Sum)
        {

            if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Redirect messages in queue"))
		    {

                # Build a list of servers trying same AD site first
                [array]$ADSites = ($ExchangeServers | Where-Object { $_.name -eq $Server }).Site
                $ADSites += ($ExchangeServers).Site |Where-Object {$_ -ne $ADSites[0]}| Select-Object -Unique
                $EligibleServers = @()
                foreach ($Site in $ADSites )
                {
                    $EligibleServers += $ExchangeServers |
                        Where-Object { $_.site -eq $Site -and $_.Name -ne $Server -and $_.name -notlike "*test*"} |
                        Sort-Object { Get-Random }
                }
                Write-Verbose "Eligible Servers: $EligibleServers"

                # Pick an eligible server not in maintentance mode.
                Foreach ( $TargetHostname in $EligibleServers.name )
                {
                    Write-Verbose "Checking $TargetHostname for maintenance mode ..."
				    Write-Progress -Activity "Waiting for [Step $i]" `
								    -Status "Checking $TargetHostname for maintenance mode ..." `
								    -PercentComplete ($EligibleServers.name.IndexOf($TargetHostname)/$EligibleServers.count * 100) -Id 1
                    Write-Verbose "Executing Get-PExMaintenanceMode"
                    $TargetServerStatus = Get-PExMaintenanceMode -Server $TargetHostname
       		        if ($TargetServerStatus.State -notcontains 'Maintenance') { Break }
                }
                Write-Progress -Activity "Completed" -Completed -Id 1

       		    if ($TargetServerStatus.State -contains 'Maintenance')
                {
                    Write-Verbose "Executing Get-Queue"
                    Get-Queue -Server $Server -ErrorAction SilentlyContinue|? {$_.DeliveryType -ne "ShadowRedundancy"} | Select-Object Identity, DeliveryType, Status, MessageCount
                    throw "[Step $i of $TotalStep] There are no eligible servers for queue redirection! Wait for queue to empty and then re-try"
                }

                $TargetFqdn = "$($TargetHostname).$($Domain)"
	            Write-Verbose "Redirecting messages to [$TargetFqdn]"
    		    
                Write-Progress -Activity "$($FunctionName)" `
							    -Status "Exchange server: $($Server)" `
							    -CurrentOperation "Current operation: [Step $i of $TotalStep] Redirecting queued messages to [$($TargetFqdn)]" `
							    -PercentComplete ($i/$($TotalStep) * 100) -Id 0
			    
                ### Save transport queue stats before redirecting messages ###
	    		Write-Verbose "Executing Redirect-Message"
                Redirect-Message -Server $Server -Target $TargetFqdn -Confirm:$false
				
				Write-Verbose "Waiting for the transport queue to empty ..."
                $Count = 0
				do
				{
					$Count += 2
                    Write-Verbose "Executing Get-Queue"
                    $QueueLength = (Get-Queue -Server $Server -ErrorAction SilentlyContinue| Measure-Object -Property MessageCount -Sum).Sum
                    If (!($QueueLength)) { $QueueLength = 0 }
					$QueuePercent = If ($QueueLength -gt 100) { 100 } Else { $QueueLength }
                    Write-Verbose "QueueLength: $QueueLength"
					Write-Progress -Activity "Waiting for [Step $i]" `
									-Status "Moving queued messages to other transport servers ..." `
									-CurrentOperation "Currently queued: $($QueueLength) messages" `
									-PercentComplete ($QueuePercent) -Id 1
					Start-Sleep -Seconds 1
				}
				while ($QueueLength -gt 0 -and $Count -lt 100 )
				Write-Progress -Activity "Completed" -Completed -Id 1
                If ($Count -ge 100)
                {
                    Write-Warning "[Step $i of $TotalStep] Timeout waiting for queue to empty. There are $($QueueLength) message outstanding. Please wait and try again." -Verbose:$True
                }
                Else
                {
                    Write-Verbose "[Step $i of $TotalStep] Queued messages are redirected to [$TargetFqdn]. The transport queue is empty." -Verbose:$True
                }
            }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Redirect messages in queue skipped by user" -Verbose:$True
            }
        }
        Else
        {
            Write-Verbose "[Step $i of $TotalStep] Redirect messages skipped. The transport queue is empty." -Verbose:$True
        }

		### Suspend Server from the DAG ###
        If ( $MailboxServer.DatabaseAvailabilityGroup -ne $null ) {    # Skip if Server is not a DAG member
		    $i++
			Write-Progress -Activity "$($FunctionName)" `
						    -Status "Exchange server: $($Server)" `
						    -CurrentOperation "Current operation: [Step $i of $TotalStep] Suspend Server from Cluster node" `
						    -PercentComplete ($i/$($TotalStep) * 100) -Id 0
		    if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Suspend Server from the DAG"))
		    {
                Write-Verbose "Executing Suspend-ClusterNode"
                If ($RunLocal)
                {
                    Suspend-ClusterNode $Server -Wait -Drain -Confirm:$false | Out-Null
                    $ClusterNodeState = (Get-ClusterNode |? {$_.Name -eq $Using:Server}).State
                }
                Else
                {
                    Invoke-Command -ComputerName $Server -ScriptBlock {
                        Suspend-ClusterNode $Using:Server -Wait -Drain -Confirm:$false | Out-Null
                    }
                    $ClusterNodeState = Invoke-Command -ComputerName $Server -ScriptBlock {
                        (Get-ClusterNode |? {$_.Name -eq $Using:Server}).State
                    }
                    $ClusterNodeState = $ClusterNodeState.value
                }   
                If ($ClusterNodeState -ne "Up") { 
                    Write-Verbose "[Step $i of $TotalStep] Suspended Server from Cluster node" -Verbose:$True
                } Else {
                    Write-Verbose "[Step $i of $TotalStep] Error occured suspending Server from Cluster node" -Verbose:$True
                }
		    }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Suspend Server from Cluster node skipped by user" -Verbose:$True
            }
        }

        ### Disable DB copy automatic activation and move any active DB copies to other DAG members ###
        If ( $MailboxServer.DatabaseAvailabilityGroup -ne $null ) {    # Skip if Server is not a DAG member
		    $i++
			Write-Progress -Activity "$($FunctionName)" `
						    -Status "Exchange server: $($Server)" `
						    -CurrentOperation "Current operation: [Step $i of $TotalStep] Disable DB copy automatic activation & Move any active DB copies to other DAG members" `
						    -PercentComplete ($i/$($TotalStep) * 100) -Id 0
		    if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Disable DB copy automatic activation & Move any active DB copies to other DAG members"))
		    {
			    ### Save mounted DB copies stats before moving ###
			    Write-Verbose "Executing Get-MailboxDatabaseCopyStatus"
                $dbMountedCount = (Get-MailboxDatabaseCopyStatus -Server $Server | Where-Object { $_.Status -eq "Mounted" } | Measure-Object -Property Name -Line).Lines
			
			    Write-Verbose "Executing Set-MailboxServer"
                Set-MailboxServer $Server -DatabaseCopyActivationDisabledAndMoveNow:$true -Confirm:$false
			    Set-MailboxServer $Server -DatabaseCopyAutoActivationPolicy Blocked -Confirm:$false
                Write-Verbose "Executing Move-ActiveMailboxDatabase"
                Move-ActiveMailboxDatabase -Server $Server
                # Dismount non-DAG databases too
                Write-Verbose "Executing Dismount-Database"
                get-mailboxdatabase -Server $Server|? {$_.ReplicationType -eq "None"}|Dismount-Database -Confirm:$False
			
			    ### Wait for any database copies that are still mounted on the server ###
			    Write-Verbose "Waiting for any database copies that are still mounted on the server ..."
                If ($dbMountedCount -gt 0) {
                    $Count = 0
			        do
			        {
				        $Count += 2
                        Write-Verbose "Executing Get-MailboxDatabaseCopyStatus"
				        $dbMounteNow = (Get-MailboxDatabaseCopyStatus -Server $Server |
                            Where-Object { $_.Status -eq "Mounted"} |
                            Measure-Object -Property Name -Line).Lines -replace '^$', '0'
				        Write-Progress -Activity "Waiting for [Step $i]" `
							           -Status "Moving $($dbMountedCount) DB copies to other DAG members ..." `
							           -CurrentOperation "Currently mounted: $($dbMounteNow) DB copies" `
							           -PercentComplete ($($dbMountedCount - [int]$dbMounteNow)/$($dbMountedCount) * 100) -Id 1
				        Start-Sleep -Seconds 1
			        }
			        while ($dbMounteNow -gt 0 -and $Count -lt 100)
                }
			    Write-Progress -Activity "Completed" -Completed -Id 1
                If ($Count -ge 100)
                {
                    Write-Warning "[Step $i of $TotalStep] Timeout waiting for databases to dismount. Please wait and try again." -Verbose:$True
                }
                Else
                {
                    Write-Verbose "[Step $i of $TotalStep] All databases are moved or dismounted" -Verbose:$True
                }
		    }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Disable & Move DB(s) Skipped by user" -Verbose:$True
            }
        }
 
 		### Dismount databases ###
        If ( $MailboxServer.DatabaseAvailabilityGroup -eq $null ) {    # Non-DAG servers
            $i++
		    Write-Progress -Activity "$($FunctionName)" `
						    -Status "Exchange server: $($Server)" `
						    -CurrentOperation "Current operation: [Step $i of $TotalStep] Dismount databases" `
						    -PercentComplete ($i/$($TotalStep) * 100) -Id 0
			### Save mounted DB copies stats before moving ###
			Write-Verbose "Executing Get-MailboxDatabaseCopyStatus"
            $dbMountedCount = (Get-MailboxDatabaseCopyStatus -Server $Server | Where-Object { $_.Status -eq "Mounted" } | Measure-Object -Property Name -Line).Lines

    	    If ($dbMountedCount)
            {
	            if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Dismount databases"))
	            {
                    Write-Verbose "Executing Dismount-Database"
                    get-mailboxdatabase -Server $Server|? {$_.ReplicationType -eq "None"}|Dismount-Database -Confirm:$False
                    get-mailboxdatabase -Server $Server|? {$_.ReplicationType -eq "None"}|Set-MailboxDatabase -MountAtStartup:$False
			
                    Write-Verbose "Waiting for all databases to dismount ..."
                    $Count = 0
			        do
			        {
				        $Count += 2
                        Write-Verbose "Executing Get-MailboxDatabaseCopyStatus"
                        $dbMounted = Get-MailboxDatabaseCopyStatus -Server $Server | Where-Object { $_.Status -eq "Mounted" }
				        $dbMounteNow = ($dbMounted | Measure-Object -Property Name -Line).Lines -replace '^$', '0'
				        Write-Progress -Activity "Waiting for [Step $i]" `
							            -Status "Moving $($dbMountedCount) Dismounting Database(s) ..." `
							            -CurrentOperation "Currently mounted: $($dbMounteNow) Database(s)" `
							            -PercentComplete ($($dbMountedCount - [int]$dbMounteNow)/$($dbMountedCount) * 100) -Id 1
				        Start-Sleep -Seconds 1
			        }
    			    while ($dbMounted -and $Count -lt 100)
        	        Write-Progress -Activity "Completed" -Completed -Id 1
                    If ($Count -ge 100)
                    {
                        Write-Warning "[Step $i of $TotalStep] Timeout waiting for databases to dismount. Please wait and try again." -Verbose:$True
                    }
                    Else
                    {
                        Write-Verbose "[Step $i of $TotalStep] All databases are dismounted" -Verbose:$True
                    }
                }
                Else
                {
                    Write-Verbose "[Step $i of $TotalStep] Dismount databases skipped by user" -Verbose:$True
                }
            }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Dismount databases skipped. There are no mounted databases." -Verbose:$True
            }
        }

		### Set Server component states to ServerWideOffline ###
		$i++
		Write-Progress -Activity "$($FunctionName)" `
						-Status "Exchange server: $($Server)" `
						-CurrentOperation "Current operation: [Step $i of $TotalStep] Set Server component states to ServerWideOffline" `
						-PercentComplete ($i/$($TotalStep) * 100) -Id 0

		if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Set Server component states to ServerWideOffline"))
		{
			Write-Verbose "Executing Set-ServerComponentState"
            Set-ServerComponentState $Server -Component ServerWideOffline -State Inactive -Requester Maintenance -Confirm:$false

            Write-Verbose "Waiting for component states to become Inactive on [$Server] ..."
            $Count = 0
		    do
		    {
			    $Count += 2
                Write-Verbose "Executing Get-PExMaintenanceMode"
                $ServerStatusAfter = Get-PExMaintenanceMode -Server $Server
			    Write-Progress -Activity "Waiting for [Step $i]" `
							    -Status "Waiting for component states to become Inactive on [$Server] ..." `
							    -CurrentOperation "Get-PExMaintenanceMode $Server = $($ServerStatusAfter.State)" `
							    -PercentComplete ( $Count ) -Id 1
		    }
    	    while ($ServerStatusAfter.State -ne 'Maintenance' -and $Count -lt 100)
            Write-Progress -Activity "Completed" -Completed -Id 1
            If ($Count -ge 100)
            {
                Write-Warning ("[Step $i of $TotalStep] Timeout waiting for Waiting for component states to become Inactive on [$Server]. " +
                    "Please wait and try Get-PExMaintenanceMode again.") -Verbose:$True
            }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Server component states set to ServerWideOffline" -Verbose:$True
            }
		}
        Else
        {
            Write-Verbose "[Step $i of $TotalStep] Set Server component states to ServerWideOffline skipped by user" -Verbose:$True
        }
        		
		### Reboot/Shutdown the server ###
		$i++
		Write-Progress -Activity "$($FunctionName)" `
						-Status "Exchange server: $($Server)" `
						-CurrentOperation "Current operation: [Step $i of $TotalStep] Reboot or Shutdown the server OS" `
						-PercentComplete ($i/$($TotalStep) * 100) -Id 0
		if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Reboot the server"))
		{
            Write-Verbose "[Step $i of $TotalStep] Restarting $Server" -Verbose:$True
            Write-Verbose "Executing Restart-Computer"
            Read-Host "Press enter to confirm RESTART of $Server"
			Restart-Computer -ComputerName $Server -Force -Confirm:$false
		}
		else
		{
			if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Shutdown the server"))
			{
                Write-Verbose "[Step $i of $TotalStep] Shutting down $Server" -Verbose:$True
                Write-Verbose "Executing Stop-Computer"
                Read-Host "Press enter to confirm SHUTDOWN of $Server"
				Stop-Computer -ComputerName $Server -Force -Confirm:$false
            }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Reboot / Shutdown Skipped by user" -Verbose:$True
            }
		}
		Write-Progress -Activity "Completed" -Completed -Id 0
	}
	End
    {
        Write-Verbose "$FunctionName :: Finished at [$(Get-Date)] on $Server" -Verbose:$True
       	Return $ServerStatusAfter
    }
}

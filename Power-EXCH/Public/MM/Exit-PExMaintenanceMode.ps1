Function Exit-PExMaintenanceMode
{
	
<#
.SYNOPSIS
	Exit Exchange Server Maintenance Mode.
.DESCRIPTION
	This function takes Exchange Server out of Maintenance Mode.
.PARAMETER Server
    Exchange server name or object representing Exchange server
.EXAMPLE
	PS C:\> Exit-PExMaintenanceMode
.EXAMPLE
	PS C:\> Exit-PExMaintenanceMode -Confirm:$false
.NOTES
	Author      :: @ps1code
	Version 1.0 :: 26-Dec-2021  :: [Release] :: Beta
	Version 1.1 :: 03-Aug-2022  :: [Improve] :: Progress bar and steps counter, Parameter free function, Disk status check
    Version 1.2 :: 27-Jun-2024  :: [Improve] :: Add ability to run from admin workstation -CoadMonkey
    Version 1.3 :: 21-Aug-2024  :: [Improve] :: Verbage updates, more verbose messages, additional checks. -CoadMonkey
                                :: [Bugfix]  :: Errors if there are non-DAG databases -CoadMonkey
.LINK
	https://ps1code.com/2024/02/05/pexmm/
#>
	
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	[Alias('Cancel-PExMaintenanceMode', 'Disable-PExMaintenanceMode', 'Exit-PExMM')]
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
        If ($Server -notin (Get-ExchangeServer).name) {
            throw "$Server is not an Exchange server. Use -Server to specify a different name."
        }
        $RunLocal = $False
        If ($env:COMPUTERNAME -eq $Server) { $RunLocal = $True }
        Write-Verbose "Executing Get-MailboxServer"
        $MailboxServer = Get-MailboxServer -Identity $Server
        If ( $MailboxServer.DatabaseAvailabilityGroup -eq $null ) {    # If Server is not a DAG member
            $TotalStep = 3
        } Else {
            Write-Verbose "Executing Get-Cluster"
            If ($RunLocal) {
                $DAG = (Get-Cluster).Name
            } Else {
                $DAG = Invoke-Command -ComputerName $Server -ScriptBlock {
                    (Get-Cluster).Name
                }
            }
            $TotalStep = 5
        }        
		$i = 0
		$WarningPreference = 'SilentlyContinue'
	}
	Process
	{
		### Bring online all Offline disks & Cancel ReadOnly flag ###
		$i++
		Write-Progress -Activity "$($FunctionName)" `
						-Status "Exchange server: $($Server)" `
						-CurrentOperation "Current operation: [Step $i of $TotalStep] Bring online $($DegradedDiskCount) degraded disks" `
						-PercentComplete ($i/$($TotalStep) * 100)
        Write-Verbose "Executing Get-Disk"
        If ($RunLocal) {
            $DegradedDisk = Get-Disk | Where-Object { $_.OperationalStatus -ne 'Online' -or $_.IsReadOnly }
        } Else {
            $DegradedDisk = Invoke-Command -ComputerName $Server -ScriptBlock {
                Get-Disk | Where-Object { $_.OperationalStatus -ne 'Online' -or $_.IsReadOnly }
            }
        }
		if ($DegradedDisk)
		{
			$DegradedDiskCount = ($DegradedDisk | Measure-Object -Property Number -Line).Lines
			$disk = if ($DegradedDiskCount -gt 1) { 'disks' }
			else { 'disk' }
			if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Bring online $($DegradedDiskCount) degraded $($disk)"))
			{
				$DegradedDisk | Where-Object { $_.OperationalStatus -ne 'Online' } | Set-Disk -IsOffline:$false
				$DegradedDisk | Where-Object { $_.IsReadOnly } | Set-Disk -IsReadOnly:$false
			}
            Write-Verbose "[Step $i of $TotalStep] $($DegradedDiskCount) degraded disks set to online and Read-Write" -Verbose:$true
		}
		else
		{
			Write-Verbose "[Step $i of $TotalStep] All disks are Online" -Verbose:$true
		}
		
		### Activate Exchange componenets [ServerWideOffline] ###
		$i++
		Write-Progress -Activity "$($FunctionName)" `
						-Status "Exchange server: $($Server)" `
						-CurrentOperation "Current operation: [Step $i of $TotalStep] Activate Exchange server componenets" `
						-PercentComplete ($i/$($TotalStep) * 100)
		if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Activate Exchange server components"))
		{
			Write-Verbose "Executing Set-ServerComponentState"
            Set-ServerComponentState $Server -Component ServerWideOffline -State Active -Requester Maintenance -Confirm:$false
			Set-ServerComponentState $Server -Component HubTransport -State Active -Requester Maintenance -Confirm:$false
    		$Count = 0
			do
			{
				$Count += 2
                Write-Progress -Activity "Waiting for [Step $i]" `
								-Status "Waiting for Exchange server componenets..." `
								-PercentComplete ($Count) -Id 1
                Write-Verbose "Executing Get-PExMaintenanceMode"
                $ServerStatusAfter = Get-PExMaintenanceMode -Server $Server
			}
			while ($ServerStatusAfter.State -ne 'Connected' -and $Count -lt 100)
		    Write-Progress -Activity "Completed" -Completed -Id 1
            If ($Count -ge 100)
            {
                Write-Warning "[Step $i of $TotalStep] Timeout waiting for Exchange server componenets. Please wait and try again." -Verbose:$True
            }
            Else
            {
                Write-Verbose "[Step $i of $TotalStep] Exchange server componenets activated" -Verbose:$true
            }
		} Else {
            Write-Verbose "[Step $i of $TotalStep] Exchange server componenets skipped" -Verbose:$true
        }
		
		### Resume DAG Cluster Node ###
        If ( $MailboxServer.DatabaseAvailabilityGroup -ne $null ) {    # Skip if Server is not a DAG member
		    $i++
			Write-Progress -Activity "$($FunctionName)" `
							-Status "Exchange server: $($Server)" `
							-CurrentOperation "Current operation: [Step $i of $TotalStep] Resume DAG Cluster Node" `
							-PercentComplete ($i/$($TotalStep) * 100)
            Write-Verbose "Executing Get-ClusterNode"
            If ($RunLocal) {
                $ClusterNode = (Get-ClusterNode -Name $Server).State -eq 'Paused'
            } Else {
                $ClusterNode = Invoke-Command -ComputerName $Server -ScriptBlock {
                    (Get-ClusterNode -Name $Using:Server).State -eq 'Paused'
                }
            }
		    if ($ClusterNode)
		    {
			    if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Resume DAG Cluster Node"))
			    {
                    Write-Verbose "Executing Resume-ClusterNode"
                    If ($RunLocal) {
                        Resume-ClusterNode -Name $Server | Out-Null
                    } Else {
                        Invoke-Command -ComputerName $Server -ScriptBlock {
                            Resume-ClusterNode -Name $Using:Server | Out-Null
                        }
                    }
                    Write-Verbose "[Step $i of $TotalStep] Resumed DAG Cluster Node" -Verbose:$true
			    } Else {
                    Write-Verbose "[Step $i of $TotalStep] Resume DAG Cluster Node skipped" -Verbose:$true
                }
		    } Else {
                Write-Verbose "[Step $i of $TotalStep] DAG Cluster Node is already Up" -Verbose:$true
            }
		}

		### Enable DB copy automatic activation ###
        If ( $MailboxServer.DatabaseAvailabilityGroup -ne $null ) {    # Skip if Server is not a DAG member
		    $i++
		    Write-Progress -Activity "$($FunctionName)" `
						    -Status "Exchange server: $($Server)" `
						    -CurrentOperation "Current operation: [Step $i of $TotalStep] Enable DB copy automatic activation" `
						    -PercentComplete ($i/$($TotalStep) * 100)
		    if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Enable DB copy automatic activation"))
		    {
			    Write-Verbose "Executing Set-MailboxServer"
                Set-MailboxServer $Server -DatabaseCopyAutoActivationPolicy Unrestricted -Confirm:$false
			    Set-MailboxServer $Server -DatabaseCopyActivationDisabledAndMoveNow:$false -Confirm:$false
    		    $Count = 0
                Write-Verbose "Executing Get-MailboxServer"
			    do
			    {
				    $Count += 2
                    Write-Verbose "Executing Get-MailboxServer"
                    $DatabaseCopyAutoActivationPolicy = (Get-MailboxServer $Server).DatabaseCopyAutoActivationPolicy
                    Write-Verbose "Waiting for DatabaseCopyAutoActivationPolicy ..."
                    Write-Progress -Activity "Waiting for [Step $i]" `
								    -Status "Waiting for DatabaseCopyAutoActivationPolicy ..." `
								    -CurrentOperation "DatabaseCopyAutoActivationPolicy = $DatabaseCopyAutoActivationPolicy" `
								    -PercentComplete ($Count) -Id 1
                    Write-Verbose "Executing Start-Sleep"
				    Start-Sleep -Seconds 1
			    }
			    while ($DatabaseCopyAutoActivationPolicy -ne "Unrestricted" -and $Count -lt 100)
		        Write-Progress -Activity "Completed" -Completed -Id 1
                If ($Count -ge 100)
                {
                    Write-Warning "[Step $i of $TotalStep] Timeout waiting for DatabaseCopyAutoActivationPolicy. Please wait and try again." -Verbose:$true
                }
                Write-Verbose "[Step $i of $TotalStep] Enabled DB copy automatic activation" -Verbose:$true
		    } Else {
                Write-Verbose "[Step $i of $TotalStep] DB copy automatic activation Skipped" -Verbose:$true
            }
        }

		### Rebalance DAG and/or mount databases ###
        $i++
		Write-Progress -Activity "$($FunctionName)" `
						-Status "Exchange server: $($Server)" `
						-CurrentOperation "Current operation: [Step $i of $TotalStep] Rebalance DAG / Mount Databases" `
						-PercentComplete ($i/$($TotalStep) * 100 - 1)
        if ($PSCmdlet.ShouldProcess("Server [$($Server)]", "[Step $i of $TotalStep] Rebalance DAG / Mount Databases"))
        {
            get-mailboxdatabase -Server $Server|? {$_.ReplicationType -eq "None"}|Set-MailboxDatabase -MountAtStartup:$True -Confirm:$False
            If ( $MailboxServer.DatabaseAvailabilityGroup -ne $null ) {    # Skip if Server is not a DAG member
                Write-Verbose "Executing Move-ActiveMailboxDatabase"
                Move-ActiveMailboxDatabase -ActivatePreferredOnServer $Server
                Write-Verbose "Executing Mount-Database"
                Get-MailboxDatabase -Server $Server|Mount-Database
                Write-Verbose "[Step $i of $TotalStep] Rebalanced DAG / Mounted Database(s)" -Verbose:$true
		    }
            Else
            {
                Write-Verbose "Executing Mount-Database"
                Get-MailboxDatabase -Server $Server|Mount-Database
                Write-Verbose "[Step $i of $TotalStep] Mounted Databases" -Verbose:$true
            }
        }
        Else
        {
            Write-Verbose "[Step $i of $TotalStep] Rebalance DAG / Mount Databases Skipped" -Verbose:$true
        }
		Write-Progress -Activity "Completed" -Completed -Id 0
	}
	End
	{
		Write-Verbose "$FunctionName :: Finished at [$(Get-Date)] on $Server" -Verbose:$True
        Return $ServerStatusAfter
	}	
}

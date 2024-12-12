<#
.SYNOPSIS
    Monitors DFS Replication backlog and generates status based on the file count in the backlog for specified replication groups.

.DESCRIPTION
    This script checks the DFS Replication backlog for specified replication groups using WMI queries and the 'dfsrdiag' command. 
    It generates success, warning, or error statuses based on the backlog file count, helping to monitor replication health.

.PARAMETER ReplicationGroupList
    An array of DFS Replication Group names to monitor. If not specified, all groups will be checked.
    This can be specified through the variable `ReplicationGroupList`.

.EXAMPLE
    ReplicationGroupList = @("Group1", "Group2")
    This will check the backlog for "Group1" and "Group2" replication groups.

.NOTES
    Author: matty-uk
    Date: ????
    Usefull links:
        https://exchange.nagios.org/directory/Addons/Monitoring-Agents/DFSR-Replication-and-BackLog/details
    #public

.CHANGELOG
    01.01.24 SAN Re-implementation for rmm
    12.12.24 SAN code cleanup

.TODO
    Add additional options for backlog threshold customization.
    move list to env 

#>



# Define parameter for specifying replication groups (default is an empty array)
Param (
    [String[]]$ReplicationGroupList = @("")  # Default is no specific group
)

# Retrieve all DFS Replication Group configurations via WMI
$ReplicationGroups = Get-WmiObject -Namespace "root\MicrosoftDFS" -Query "SELECT * FROM DfsrReplicationGroupConfig"

# Filter replication groups if specific group names are provided
if ($ReplicationGroupList) {
    $FilteredReplicationGroups = @()
    foreach ($ReplicationGroup in $ReplicationGroupList) {
        $FilteredReplicationGroups += $ReplicationGroups | Where-Object { $_.ReplicationGroupName -eq $ReplicationGroup }
    }

    # Exit with UNKNOWN status if no groups match
    if ($FilteredReplicationGroups.Count -eq 0) {
        Write-Host "UNKNOWN: None of the specified group names were found."
        exit 3
    } else {
        $ReplicationGroups = $FilteredReplicationGroups
    }
}

# Initialize counters for success, warning, and error
$SuccessCount = 0
$WarningCount = 0
$ErrorCount = 0

# Initialize an array to store output messages
$OutputMessages = @()

# Iterate through each DFS Replication Group
foreach ($ReplicationGroup in $ReplicationGroups) {
    # Query for DFS Replicated Folder configurations for the current replication group
    $ReplicatedFoldersQuery = "SELECT * FROM DfsrReplicatedFolderConfig WHERE ReplicationGroupGUID='" + $ReplicationGroup.ReplicationGroupGUID + "'"
    $ReplicatedFolders = Get-WmiObject -Namespace "root\MicrosoftDFS" -Query $ReplicatedFoldersQuery

    # Query for DFS Replication Connection configurations for the current replication group
    $ReplicationConnectionsQuery = "SELECT * FROM DfsrConnectionConfig WHERE ReplicationGroupGUID='" + $ReplicationGroup.ReplicationGroupGUID + "'"
    $ReplicationConnections = Get-WmiObject -Namespace "root\MicrosoftDFS" -Query $ReplicationConnectionsQuery

    # Iterate through each DFS Replication Connection for the current replication group
    foreach ($ReplicationConnection in $ReplicationConnections) {
        $ConnectionName = $ReplicationConnection.PartnerName

        # Check if the connection is enabled
        if ($ReplicationConnection.Enabled -eq $True) {
            # Iterate through each DFS Replicated Folder for the current connection
            foreach ($ReplicatedFolder in $ReplicatedFolders) {
                $ReplicationGroupName = $ReplicationGroup.ReplicationGroupName
                $ReplicatedFolderName = $ReplicatedFolder.ReplicatedFolderName

                # Execute the 'dfsrdiag' command to get backlog information
                $BacklogCommand = "dfsrdiag Backlog /RGName:'$ReplicationGroupName' /RFName:'$ReplicatedFolderName' /SendingMember:$ConnectionName /ReceivingMember:$env:ComputerName"
                $BacklogOutput = Invoke-Expression -Command $BacklogCommand

                $BacklogFileCount = 0
                # Parse the 'dfsrdiag' output to retrieve the backlog file count
                foreach ($Item in $BacklogOutput) {
                    if ($Item -ilike "*Backlog File count*") {
                        $BacklogFileCount = [int]$Item.Split(":")[1].Trim()
                    }
                }

                # Generate status messages based on backlog file count and update counters
                if ($BacklogFileCount -eq 0) {
                    $OutputMessages += "OK: $BacklogFileCount files in backlog for $ConnectionName->$env:ComputerName in $ReplicationGroupName"
                    $SuccessCount++
                } elseif ($BacklogFileCount -lt 10) {
                    $OutputMessages += "WARNING: $BacklogFileCount files in backlog for $ConnectionName->$env:ComputerName in $ReplicationGroupName"
                    $WarningCount++
                } else {
                    $OutputMessages += "CRITICAL: $BacklogFileCount files in backlog for $ConnectionName->$env:ComputerName in $ReplicationGroupName"
                    $ErrorCount++
                }
            }
        }
    }
}

# Generate the final status based on the success, warning, and error counters
if ($ErrorCount -gt 0) {
    Write-Host "CRITICAL: $ErrorCount errors, $WarningCount warnings, and $SuccessCount successful replications."
    Write-Host "$OutputMessages"
    $host.SetShouldExit(2)
    exit 2
} elseif ($WarningCount -gt 0) {
    Write-Host "WARNING: $WarningCount warnings, and $SuccessCount successful replications."
    Write-Host "$OutputMessages"
    $host.SetShouldExit(1)
    exit 1
} else {
    Write-Host "OK: $SuccessCount successful replications."
    Write-Host "$OutputMessages"
    $host.SetShouldExit(0)
    exit 0
}

<#
.SYNOPSIS
    This script performs health checks on a machine with SQL Server installed.

.DESCRIPTION
    The script checks various aspects of SQL Server health, including version, blocked requests, 
    and availability group synchronization. It provides a modular approach with separate functions 
    for each check.

.NOTES
    Author: SAN
    Date: 01.01.2024
    #public

.CHANGELOG
    SAN 12.12.2023 Changed outputs
    SAN 14.03.2024 Added availability group checks
    SAN 02.07.2025 Centralised querries executions
    
.TODO
    Improve error handling


#>
function Get-SqlInstances {
    $computername = $env:COMPUTERNAME
    $instances = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server" -Name "InstalledInstances").InstalledInstances
    $serverInstances = @()

    foreach ($instance in $instances) {
        if ($instance -eq "MSSQLSERVER") {
            $serverInstances += "localhost"
        } else {
            try {
                # Try without port first
                $serverInstances += "$computername\$instance"
                # Optionally, also add with port to test
                $port = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\$instance\MSSQLServer\SuperSocketNetLib\Tcp" -Name "TcpPort" -ErrorAction SilentlyContinue).TcpPort
                if ($port) {
                    $serverInstances += "$computername\$instance,$port"
                }
            } catch {
                Write-Host "Warning: Could not retrieve port for instance $instance"
            }
        }
    }
    return $serverInstances
}
function Ensure-SqlCmdAvailable {
    if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
        try {
            Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction Stop
            Add-PSSnapin SqlServerProviderSnapin100 -ErrorAction Stop
        } catch {
            throw "SQL Cmdlets are not available and could not be loaded."
        }
    }
}

function Run-SqlQuery {
    param (
        [string]$Query,
        [string]$Description,
        [switch]$ReturnResults
    )

    Write-Host "Running: $Description"
    $serverInstances = Get-SqlInstances
    $errorEncountered = $false
    $allResults = @()

    Ensure-SqlCmdAvailable

    foreach ($serverInstance in $serverInstances) {
        try {
            $result = Invoke-Sqlcmd -ServerInstance $serverInstance -Query $Query -QueryTimeout 30 -ErrorAction Stop
            if (-not $result) {
                Write-Host "OK: $serverInstance - No results"
            } else {
                Write-Host "OK: $serverInstance - Results:"
                $result | Format-Table -AutoSize
            }
            if ($ReturnResults) {
                $allResults += [pscustomobject]@{
                    ServerInstance = $serverInstance
                    Result = if ($result) { $result } else { @() }
                }
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message) for $serverInstance"
            $errorEncountered = $true
        }
    }
    if ($errorEncountered) {
        return "Error"
    } else {
        if ($ReturnResults) {
            return $allResults
        }
        return "OK"
    }
}


function Get-SqlServerVersion {
    $query = "SELECT @@VERSION;"
    Write-Host "Running: Get SQL Server Version"

    $serverInstances = Get-SqlInstances
    $errorEncountered = $false

    Ensure-SqlCmdAvailable

    foreach ($serverInstance in $serverInstances) {
        Write-Host "`nQuerying instance: $serverInstance"
        try {
            $result = Invoke-Sqlcmd -ServerInstance $serverInstance -Query $query -QueryTimeout 30 -ErrorAction Stop
            if (-not $result) {
                #Write-Host "DEBUG: No results returned from $serverInstance."
                $errorEncountered = $true
            } else {
                #Write-Host "DEBUG: Raw result object type: $($result.GetType().FullName)"
                #Write-Host "DEBUG: Result count: $($result.Count)"
                #Write-Host "DEBUG: Result content:"
                #$result | Format-List | Out-String | Write-Host
                Write-Host "OK: $serverInstance SQL Version: $($result.Column1)"
            }
        } catch {
            Write-Host "ERROR: Exception querying $serverInstance : $($_.Exception.Message)"
            $errorEncountered = $true
        }
    }

    if ($errorEncountered) {
        return "Error"
    } else {
        return "OK"
    }
}



function Get-BlockedSqlRequests {
    $query = @"
USE master
SELECT db.name AS DBName,
       tl.request_session_id,
       wt.blocking_session_id,
       OBJECT_NAME(p.OBJECT_ID) AS BlockedObjectName,
       tl.resource_type,
       h1.TEXT AS RequestingText,
       h2.TEXT AS BlockingText,
       tl.request_mode
FROM sys.dm_tran_locks AS tl
JOIN sys.databases db ON db.database_id = tl.resource_database_id
JOIN sys.dm_os_waiting_tasks AS wt ON tl.lock_owner_address = wt.resource_address
JOIN sys.partitions AS p ON p.hobt_id = tl.resource_associated_entity_id
JOIN sys.dm_exec_connections ec1 ON ec1.session_id = tl.request_session_id
JOIN sys.dm_exec_connections ec2 ON ec2.session_id = wt.blocking_session_id
CROSS APPLY sys.dm_exec_sql_text(ec1.most_recent_sql_handle) AS h1
CROSS APPLY sys.dm_exec_sql_text(ec2.most_recent_sql_handle) AS h2
"@
    return Run-SqlQuery -Query $query -Description "Get Blocked SQL Requests"
}
function Get-SqlAgSyncStatus {
    Write-Host "Running: Get SQL Availability Group Sync Status"

    $instanceName = (Get-Item 'HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL').Property[0]
    $server = "$($env:COMPUTERNAME)\$instanceName"

    Write-Host "Detected SQL Server Instance: $server"

    $agQuery = @"
SELECT c.name, s.synchronization_health
FROM sys.availability_groups_cluster c
JOIN sys.dm_hadr_availability_group_states s ON c.group_id = s.group_id
WHERE LOWER(s.primary_replica) = LOWER('$server')
   OR LOWER('$server') IN (
       SELECT LOWER(replica_server_name)
       FROM sys.availability_replicas
   );
"@

    $agResults = Run-SqlQuery -Query $agQuery -Description "Get Availability Group Synchronization Status" -ReturnResults

    if ($agResults -eq "Error") {
        Write-Host "Failed to retrieve Availability Group synchronization status."
        return "Error"
    }

    $agData = $agResults | Where-Object { $_.ServerInstance -eq $server }

    if (-not $agData -or $agData.Result.Count -eq 0) {
        Write-Host "OK: $server AG SYNCHRO - No Availability Groups found."
        return "OK"
    }

    $description = ""
    $statusLevel = 0

    foreach ($row in $agData.Result) {
        switch ($row.synchronization_health) {
            0 { 
                $statusLevel = [Math]::Max($statusLevel, 2)
                $description += "$($row.name): Not Healthy "
            }
            1 { 
                $statusLevel = [Math]::Max($statusLevel, 1)
                $description += "$($row.name): Partially Healthy "
            }
            2 { 
                $description += "$($row.name): Healthy "
            }
        }
    }

    $status = @("OK", "WARNING", "CRITICAL")[$statusLevel]
    Write-Host "${status}: $server AG SYNCHRO - $description"
    return $status
}

function Check-SqlServerInstallation {
    if (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue) {
        return $true
    } else {
        Write-Host "SQL Server is not installed on this device"
        return $false
    }
}

function Get-SqlCurrentUser {

    $query = "SELECT SUSER_NAME() AS LoginName, USER_NAME() AS UserName;"

    $results = Run-SqlQuery -Query $query -Description "Get current SQL user" -ReturnResults

    if ($results -eq "Error" -or $results.Count -eq 0) {
        Write-Host "Failed to retrieve current user information."
        return "Error"
    }

    foreach ($res in $results) {
        if (-not $res.ServerInstance -or -not $res.Result) {
            # Skip empty results
            continue
        }

        $loginName = ""
        $userName = ""

        if ($res.Result -is [System.Data.DataRow]) {
            $loginName = $res.Result.Item("LoginName")
            $userName = $res.Result.Item("UserName")
        }
        elseif ($res.Result -is [System.Data.DataTable]) {
            if ($res.Result.Rows.Count -gt 0) {
                $row = $res.Result.Rows[0]
                $loginName = $row.Item("LoginName")
                $userName = $row.Item("UserName")
            }
        }
        elseif ($res.Result -is [System.Collections.IEnumerable]) {
            $firstRow = $res.Result | Select-Object -First 1
            if ($firstRow) {
                $loginName = $firstRow.LoginName
                $userName = $firstRow.UserName
            }
        }

        Write-Host "Connected as: $loginName ($userName) on $($res.ServerInstance)"
    }
}


# MAIN EXECUTION BLOCK
if (Check-SqlServerInstallation) {

    Get-SqlCurrentUser

    $result1 = Get-SqlServerVersion
    $result2 = Get-BlockedSqlRequests
    $result3 = Get-SqlAgSyncStatus

    if ($result1 -eq "OK" -and $result2 -eq "OK" -and $result3 -eq "OK") {
        Write-Host "OK: All components are functioning properly"
    } else {
        $errorComponents = @()
        if ($result1 -ne "OK") { $errorComponents += "SQL Server Version Check" }
        if ($result2 -ne "OK") { $errorComponents += "Blocked SQL Requests Check" }
        if ($result3 -ne "OK") { $errorComponents += "AG Synchronization Check" }

        $errorList = $errorComponents -join ", "
        Write-Host "KO: Some components encountered errors. Errors in: $errorList"
        Exit 1
    }
}

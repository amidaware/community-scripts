<#
.SYNOPSIS
    This script performs health checks on a machine with SQL Server installed.

.DESCRIPTION
    The script checks various aspects of SQL Server health, including version and blocked requests.
    It provides a modular approach with separate functions for each check.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public
    
.TODO


.CHANGELOG
    SAN 12.12.24 Changed outputs
    SAN 14.03.24 Added availability groups checks
#>

function Get-SqlServerVersion {
    Write-Host "function Get-SqlServerVersion"
    
    $computername = $env:computername
    $instances = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server" -Name "InstalledInstances").InstalledInstances

    $errorEncountered = $false  # Initialize flag for tracking errors

    foreach ($instance in $instances) {
        if ($instance -eq "MSSQLSERVER") {
            $serverInstance = "localhost"
        } else {
            $portsql = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\$instance\MSSQLServer\SuperSocketNetLib\Tcp" -Name "TcpPort").TcpPort
            $serverInstance = "$computername\$instance,$portsql"
        }

        $cmdName = 'Invoke-Sqlcmd'

        if (-not (Get-Command $cmdName -ErrorAction SilentlyContinue)) {
            Add-PSSnapin SqlServerCmdletSnapin100
            Add-PSSnapin SqlServerProviderSnapin100
        }

        try {
            $version = Invoke-Sqlcmd -ServerInstance $serverInstance -Query "SELECT @@VERSION;" -QueryTimeout 3 -ErrorAction Stop

            if (-not $version) {
                Write-Host "Error: SQL Check Failed for $serverInstance"
                $errorEncountered = $true  # Set flag to indicate error
            } else {
                Write-Host "OK: $($serverInstance) $($version[0].replace("`n`t"," "))"
            }
        } catch {
            Write-Host "Error: $($_.Exception.Message) for $serverInstance"
            $errorEncountered = $true  # Set flag to indicate error
        }
    }

    if ($errorEncountered) {
        return "Error"  # Return "Error" if any error occurred during the process
    } else {
        return "OK"  # Return "OK" if no errors occurred
    }
}




function Get-BlockedSqlRequests {
    Write-Host "function Get-BlockedSqlRequests"
    
    $computername = $env:computername
    $instances = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server" -Name "InstalledInstances").InstalledInstances

    $errorEncountered = $false  # Initialize flag for tracking errors

    foreach ($instance in $instances) {
        if ($instance -eq "MSSQLSERVER") {
            $serverInstance = "localhost"
        } else {
            $portsql = (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\$instance\MSSQLServer\SuperSocketNetLib\Tcp" -Name "TcpPort").TcpPort
            $serverInstance = "$computername\$instance,$portsql"
        }

        $mysqlrequest = @"
        USE master
        SELECT db.name DBName,
        tl.request_session_id,
        wt.blocking_session_id,
        OBJECT_NAME(p.OBJECT_ID) BlockedObjectName,
        tl.resource_type,
        h1.TEXT AS RequestingText,
        h2.TEXT AS BlockingTest,
        tl.request_mode
        FROM sys.dm_tran_locks AS tl
        INNER JOIN sys.databases db ON db.database_id = tl.resource_database_id
        INNER JOIN sys.dm_os_waiting_tasks AS wt ON tl.lock_owner_address = wt.resource_address
        INNER JOIN sys.partitions AS p ON p.hobt_id = tl.resource_associated_entity_id
        INNER JOIN sys.dm_exec_connections ec1 ON ec1.session_id = tl.request_session_id
        INNER JOIN sys.dm_exec_connections ec2 ON ec2.session_id = wt.blocking_session_id
        CROSS APPLY sys.dm_exec_sql_text(ec1.most_recent_sql_handle) AS h1
        CROSS APPLY sys.dm_exec_sql_text(ec2.most_recent_sql_handle) AS h2
"@

        $cmdName = 'Invoke-Sqlcmd'

        if (-not (Get-Command $cmdName -ErrorAction SilentlyContinue)) {
            Add-PSSnapin SqlServerCmdletSnapin100
            Add-PSSnapin SqlServerProviderSnapin100
        }

        try {
            $result = Invoke-Sqlcmd -ServerInstance $serverInstance -Query $mysqlrequest -QueryTimeout 60 -ErrorAction Stop

            if (-not $result) {
                Write-Host "OK: $($serverInstance) No Blocking Requests"
            } else {
                Write-Host "Error: Unable to retrieve blocked requests for $($serverInstance). $($result[0].Exception.Message)"
                $errorEncountered = $true  # Set flag to indicate error
            }
        } catch {
            Write-Host "Error: Unable to retrieve blocked requests for $($serverInstance). $($Error[0].Exception.Message)"
            $errorEncountered = $true  # Set flag to indicate error
        }
    }

    if ($errorEncountered) {
        return "Error" 
    } else {
        return "OK"
    }
}

Function Get-SqlAgSyncStatus {
    Write-Host "Function Get-SqlAgSyncStatus"
    
    $server = "$( $env:COMPUTERNAME)\$( (Get-Item 'HKLM:\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL').Property[0])"
    Write-Host "Detected SQL Server Instance: $server"
    
    Function RunQuery($query) {
        Try {
            $conn = New-Object System.Data.SqlClient.SqlConnection
            $conn.ConnectionString = "Server=$server;Database=master;Integrated Security=True"
            $conn.Open()
            
            $userQuery = "SELECT SUSER_NAME(), USER_NAME();"
            $cmdUser = New-Object System.Data.SqlClient.SqlCommand($userQuery, $conn)
            $userReader = $cmdUser.ExecuteReader()
            If ($userReader.Read()) {
                Write-Host "Connected as: $($userReader.GetString(0)) ($($userReader.GetString(1)))"
            }
            $userReader.Close()
            
            Write-Host "SQL Connection Successful: $server"
            
            $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
            $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
            $dataSet = New-Object System.Data.DataSet
            $adapter.Fill($dataSet) | Out-Null
            $conn.Close()
            
            return $dataSet.Tables[0]
        } Catch {
            Write-Host "SQL Error: $_"
            return $null
        }
    }
    
    $query = "SELECT c.name, s.synchronization_health FROM sys.availability_groups_cluster c 
    JOIN sys.dm_hadr_availability_group_states s ON c.group_id = s.group_id 
    WHERE LOWER(s.primary_replica) = LOWER('$server') OR LOWER('$server') IN 
    (SELECT LOWER(replica_server_name) FROM sys.availability_replicas);"
    
    $result = RunQuery $query 
    
    if ($null -eq $result -or $result.Rows.Count -eq 0) {
        Write-Host "OK : $server AG SYNCHRO : No Availability Groups found."
        return "OK"
    }
    
    Write-Host "Query Result Count: $($result.Rows.Count)"
    Write-Host "Query Result: $($result | Out-String)"
    
    $description = ""
    $statusLevel = 0
    foreach ($row in $result) {
        switch ($row.synchronization_health) {
            0 { $statusLevel = [Math]::Max($statusLevel, 2); $description += "$($row.name): Not Healthy " }
            1 { $statusLevel = [Math]::Max($statusLevel, 1); $description += "$($row.name): Partially Healthy " }
            2 { $description += "$($row.name): Healthy " }
        }
    }
    
    $status = @("OK", "WARNING", "CRITICAL")[$statusLevel]
    Write-Host "$status : $server AG SYNCHRO : $description"
    return $status
}



function Check-SqlServerInstallation {
    # Check if Invoke-Sqlcmd is available
    if (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue) {
        return $true
    } else {
        Write-Host "SQL Server is not installed on this device"
        return $false
    }
}

# Check if SQL Server is installed before proceeding with health checks
if (Check-SqlServerInstallation) {
    $cmdName = 'Invoke-Sqlcmd'

    # Run each function and report the result
    $result1 = Get-SqlServerVersion
    $result2 = Get-BlockedSqlRequests
    $result3 = Get-SqlAgSyncStatus

    # Check the results and provide the overall status
    if ($result1 -eq "OK" -and $result2 -eq "OK" -and $result3 -eq "OK") {
        Write-Host "OK: All components are functioning properly"
    } else {
        $errorComponents = @()

        if ($result1 -ne "OK") {
            $errorComponents += "SQL Server Version Check"
        }

        if ($result2 -ne "OK") {
            $errorComponents += "Blocked SQL Requests Check"
        }
        
        if ($result3 -ne "OK") {
            $errorComponents += "AG Synchronization Check"
        }

        $errorList = $errorComponents -join ", "
        Write-Host "Overall Status: Some components encountered errors. Errors in: $errorList"
        Exit 1
    }
}


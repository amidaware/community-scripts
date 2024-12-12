<#
.SYNOPSIS
    Collects Microsoft SQL Server instance details for licensing and capacity reporting.

.DESCRIPTION
    This script identifies running Microsoft SQL Server instances on the local machine, 
    retrieves their edition, and provides detailed hardware and configuration information. 
    It includes data such as the number of CPUs, cores, and SQL Server capacity limits based on the edition. 

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG

.TODO

#>


function Get-MSSQLVersion {
    $SQLInstances = Get-Service -Name MSSQL* | Where-Object { $_.Status -eq "Running" -and $_.Name -notlike 'MSSQLFDLauncher*' -and $_.Name -notlike 'MSSQLLaunchpad*' -and $_.Name -notlike '*WID*' -and $_.Name -notlike 'MSSQLServerOLAPService*' } | Select-Object -Property @{label='InstanceName';expression={$_.Name -replace '^.*\$'}}

    if ($SQLInstances.Count -eq 0) {
        Write-Host "MS SQL not found"
        return
    }

    foreach ($SQLInstance in $SQLInstances.InstanceName) {
        $ServerName = $env:COMPUTERNAME
        
        # Get Default SQL Server instance's Edition
        if ($SQLInstance -like 'MSSQLSERVER') {
            $SQLName = $ServerName
        } else {
            $SQLName = "$ServerName\$SQLInstance"
        }
        
        $sqlconn = New-Object System.Data.SqlClient.SqlConnection("server=$SQLName;Trusted_Connection=true")
        $query = "SELECT SERVERPROPERTY('Edition') AS Edition, SERVERPROPERTY('MachineName') AS MachineName, SERVERPROPERTY('IsClustered') AS [Clustered];"
        
        $sqlconn.Open()
        $sqlcmd = New-Object System.Data.SqlClient.SqlCommand ($query, $sqlconn)
        $sqlcmd.CommandTimeout = 0
        $dr = $sqlcmd.ExecuteReader()
        
        while ($dr.Read()) { 
            $SQLEdition = $dr.GetValue(0)
            $MachineName = $dr.GetValue(1)
            $IsClustered = $dr.GetValue(2)
        }
        
        $dr.Close()
        $sqlconn.Close()
        
        # Get processors information            
        $CPU = Get-WmiObject -Class Win32_Processor
        
        # Get Computer model information
        $OS_Info = Get-WmiObject -Class Win32_ComputerSystem
        
        # Reset number of cores and use count for the CPUs counting
        $CPUs = 0
        $Cores = 0
        
        foreach ($Processor in $CPU) {
            $CPUs++
            # Count the total number of cores         
            $Cores += $Processor.NumberOfCores
        } 
        
        Write-Host "ServerName: $ServerName"
        Write-Host "Model: $($OS_Info.Model)"
        Write-Host "InstanceName: $SQLInstance"
        Write-Host "DataSource: $($sqlconn.DataSource)"
        Write-Host "Edition: $SQLEdition"
        Write-Host "SocketNumber: $CPUs"
        Write-Host "TotalCores: $Cores"
        $CoresPerSocketCPUsRatio = $Cores / $CPUs
        Write-Host "Cores per Socket/CPUs Ratio: $CoresPerSocketCPUsRatio"
        $ResumeCapacityLimits = 
            if ($SQLEdition -like "Developer*") { "Max SQL Server compute capacity: OS max" }
            elseif ($SQLEdition -like "Express*") { "Max SQL Server compute capacity: 1 sockets or 4 cores" }
            elseif ($SQLEdition -like "Standard*") { "Max SQL Server compute capacity: Lesser of 4 sockets or 24 cores" }
            elseif ($SQLEdition -like "Web*") { "Max SQL Server compute capacity Lesser of 4 sockets or 16 cores" }
            else { "SQL edition not detected" }
        Write-Host "ResumeCapacityLimits: $ResumeCapacityLimits"
    }
}

Get-MSSQLVersion
<#
.SYNOPSIS
    This script checks the protection status of ESET Security using the `ermm.exe` command-line tool 
    and provides an appropriate exit code based on the status.

.DESCRIPTION
    The script executes the ESET Security command to retrieve the protection status. 
    If the system is protected, it exits with a code of 0. If the license is about to expire, 
    it exits with a code of 1, and if the protection status is not found or any other error occurs, 
    it exits with a code of 2. Debug output is provided in cases where the protection status or 
    license expiration is detected but the command's output is unexpected.

.NOTES
    Author: SAN
    Usefull links:
        https://help.eset.com/eea/12/en-US/rmm_command_line.html?idh_config_ermm.html
    #public

.TODO
    Get the output and convert to json to use it and output more details

#>

try {
    $commandOutput = & "C:\Program Files\ESET\ESET Security\ermm.exe" get protection-status 2>&1

    if ($commandOutput -match "You are protected") {
        Write-Host "You are protected"
        $host.SetShouldExit(0)
        exit 0
    } elseif ($commandOutput -match "License expires") {
        Write-Host "License expires"
        Write-Host "Debug output:"
        Write-Host "$commandOutput"
        $host.SetShouldExit(1)
        exit 1
    } else {
        Write-Host "Protection status not found"
        Write-Host "Debug output:"
        Write-Host "$commandOutput"
        $host.SetShouldExit(2)
        exit 2
    }
} catch {
    Write-Host "Error executing the command: $_"
    Write-Host "ESET is not installed"
    $host.SetShouldExit(2)
    exit 2
}
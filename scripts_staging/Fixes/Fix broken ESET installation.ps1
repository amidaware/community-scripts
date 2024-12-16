<#
.SYNOPSIS
    This PowerShell script is designed to fix a broken installation of ESET Security that generaly happens after an update.

.DESCRIPTION
    The script performs the following actions:
    1. Deletes the ESET Security directory in Program Files.
    2. Deletes the ESET Security directory in ProgramData.
    3. Stops and deletes the ekrn service.
    4. Deletes the registry key for the ekrn service.

.EXEMPLE
    force_execution=true

.NOTES
    Author: SAN
    Date: 19.08.24
    #public

.CHANGELOG


#>

# Check if the environment variable 'force_execution' is set to 'true'
if ($env:force_execution -eq 'true') {
    Write-Host "Force execution is enabled. Skipping file existence check."
} else {
    # Only check if the file exists if force_execution is not enabled
    if (Test-Path "C:\Program Files\ESET\ESET Security\ermm.exe") {
        Write-Host "Error: The file 'ermm.exe' exists at the specified path. This script may not work as expected."
        exit 0
    } else {
        Write-Host "The file 'ermm.exe' does not exist. The script can proceed."
    }
}


Write-Host "Fixing broken installation of ESET Security..."

# Define paths and service name
$ESET_PROG_FILES_DIR = "C:\Program Files\ESET\ESET Security"
$ESET_PROG_DATA_DIR = "C:\ProgramData\ESET\ESET Security"
$serviceName = "ekrn"
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\ekrn"

# Delete the ESET Security directory in Program Files
if (Test-Path $ESET_PROG_FILES_DIR) {
    Write-Host "Deleting directory: $ESET_PROG_FILES_DIR"
    Remove-Item -Recurse -Force $ESET_PROG_FILES_DIR
} else {
    Write-Host "Directory not found: $ESET_PROG_FILES_DIR"
}

# Delete the ESET Security directory in ProgramData
if (Test-Path $ESET_PROG_DATA_DIR) {
    Write-Host "Deleting directory: $ESET_PROG_DATA_DIR"
    Remove-Item -Recurse -Force $ESET_PROG_DATA_DIR
} else {
    Write-Host "Directory not found: $ESET_PROG_DATA_DIR"
}

# Stop and delete the ekrn service
if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping service: $serviceName"
    Stop-Service -Name $serviceName -Force
    Write-Host "Deleting service: $serviceName"
    Remove-Service -Name $serviceName -Force
} else {
    Write-Host "Service not found: $serviceName"
}

# Delete the registry key
if (Test-Path $registryPath) {
    Write-Host "Deleting registry key: $registryPath"
    Remove-Item -Path $registryPath -Recurse -Force
} else {
    Write-Host "Registry key not found: $registryPath"
}

Write-Host "Operation completed."
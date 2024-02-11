<#
.SYNOPSIS
   Toggle Network Interface Card (NIC) Status
   This script alternates between enabling and disabling the specified NIC.

.DESCRIPTION
   This PowerShell script will toggle the status of the specified Network Interface Card (NIC). If you disable the active NIC you may have a script timeout because you can't get the return data back

.PARAMETER NICName
   The name of the Network Interface Card (NIC) to toggle.

.EXEMPLE
    -NICName 'Embedded LOM 1 Port 2'

.NOTES
    v1.0 2/11/2024 Orbitturner
    
#>

param (
    [string]$NICName
)

# Function to get a list of available NICs with information
function Get-NICList {
    Get-NetAdapter | Select-Object Name, Status, InterfaceDescription
}

# Check if NICName is provided
if (-not $NICName) {
    Write-Output "NICName parameter is required. Available NICs:"
    Get-NICList
    Exit 1
}

$up = "Up"
$disabled = "Disabled"

# Check the current status of the specified NIC
$lanStatus = Get-NetAdapter | Select-Object Name, Status | Where-Object { $_.Status -match $up -and $_.Name -match $NICName }

# Toggle the NIC status based on the current state
if ($lanStatus) {
    Write-Output ("Disabling $NICName")
    Disable-NetAdapter -Name $NICName -Confirm:$false
}
else {
    Write-Output ("Enabling $NICName")
    Enable-NetAdapter -Name $NICName -Confirm:$false
}

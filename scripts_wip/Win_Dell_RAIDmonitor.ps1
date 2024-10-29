<#
.SYNOPSIS
    Check Dell PERC RAID status using OpenManage command-line interface (OMSA).

.DESCRIPTION
    This script checks the RAID status of Dell systems using OMSA. It scans for issues in both virtual and physical disks on all controllers and outputs the results. If the `-debug` switch is provided, detailed disk information is also displayed.

.PARAMETER debug
    Switch to enable debug output.

.NOTES
    v1.3 7/17/2024 silversword411 Adding exit conditions, debug, cleaned output
#>

param (
    [switch]$debug
)


# For setting debug output level. -debug switch will set $debug to true
if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

# Check Dell RAID status using OpenManage command-line interface (OMSA)

# Define the OMSA installation directory
$omsaDir = "C:\Program Files\Dell\SysMgt\oma\bin"

# Change to the OMSA installation directory
Set-Location $omsaDir

# Initialize variables to track if there are any issues and their reasons
$hasProblems = $false
$problemReasons = @()

# Get a list of all controllers
$controllerOutput = .\omreport storage controller

# Extract controller IDs
$controllerIds = $controllerOutput | Select-String "ID" -Context 0, 1 | ForEach-Object {
    if ($_.Line -match 'ID\s+:\s+(\d+)') {
        $matches[1]
    }
}

# Iterate through each controller ID to list its vdisks and physical disks
foreach ($controllerId in $controllerIds) {
    # List vdisks for the current controller
    $vdiskList = .\omreport storage vdisk controller=$controllerId
    # List physical disks for the current controller
    $pdiskList = .\omreport storage pdisk controller=$controllerId

    # Check for issues in the virtual disks
    $vdiskList -split "`r`n" | ForEach-Object {
        if ($_ -match "Status\s+:\s+Failure Predicted\s+:\s+Yes|State\s+:\s+Failed") {
            $hasProblems = $true
            $problemReasons += "Virtual Disk issue on Controller ID ${controllerId}: $_"
        }
    }

    # Check for issues in the physical disks
    $pdiskList -split "`r`n" | ForEach-Object {
        if ($_ -match "Status\s+:\s+Failure Predicted\s+:\s+Yes|State\s+:\s+Failed") {
            $hasProblems = $true
            $problemReasons += "Physical Disk issue on Controller ID ${controllerId}: $_"
        }
    }
}

function Display-ControllerDisks {
    # Display the details after the check
    Write-Debug "-----------------------"
    foreach ($controllerId in $controllerIds) {
        # List vdisks for the current controller
        $vdiskList = .\omreport storage vdisk controller=$controllerId
        # List physical disks for the current controller
        $pdiskList = .\omreport storage pdisk controller=$controllerId

        # Format and display the vdisk list with the controller ID
        Write-Host "Controller ID: $controllerId"
        Write-Host "Virtual Disks:"
        $vdiskList -split "`r`n" | ForEach-Object { "    $_" }
    
        # Format and display the physical disk list for the controller
        Write-Host "Physical Disks:"
        $pdiskList -split "`r`n" | ForEach-Object { "    $_" }

        Write-Host "-----------------------"
    }
}

# Output error or success message at the beginning
if ($hasProblems) {
    Write-Host "Problems detected in RAID configuration. Exiting with status code 1."
    Write-Host "Reasons:"
    $problemReasons | ForEach-Object { Write-Host "    $_" }
    if ($debug) { Display-ControllerDisks }
    exit 1
}
else {
    Write-Host "No problems detected in RAID configuration. Exiting with status code 0."
    if ($debug) { Display-ControllerDisks }
    exit 0
}
<#
.Synopsis
    Software Install and Removal Detection - Reports new installs and removals without considering version numbers.
.DESCRIPTION
    This script compares the current installed software list from the registry with a previous state.
.VERSION
    v1.0 11/23/2024
#>

Function Foldercreate {
    param (
        [Parameter(Mandatory = $false)]
        [String[]]$Paths
    )
    
    foreach ($Path in $Paths) {
        if (!(Test-Path $Path)) {
            New-Item -ItemType Directory -Force -Path $Path
        }
    }
}
Foldercreate -Paths "$env:ProgramData\TacticalRMM\temp", "$env:ProgramData\TacticalRMM\logs"

# Define file paths
$previousStateFile = "$env:ProgramData\TacticalRMM\installed_software.json"
$logFile = "$env:ProgramData\TacticalRMM\logs\software_changes.log"

# Function to get installed software from the registry
function Get-InstalledSoftware {
    $installedSoftware = @()

    # Get software from 64-bit and 32-bit registry paths
    $installedSoftware += Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Select-Object DisplayName, DisplayVersion
    $installedSoftware += Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Select-Object DisplayName, DisplayVersion

    # Filter out entries without a valid DisplayName
    $installedSoftware = $installedSoftware | Where-Object { $_.DisplayName -ne $null -and $_.DisplayName -ne '' }

    # Strip version number patterns from DisplayName and remove duplicates
    $installedSoftware = $installedSoftware | ForEach-Object {
        if ($_.DisplayVersion -and $_.DisplayName -like "*$($_.DisplayVersion)*") {
            $_.DisplayName = $_.DisplayName -replace [regex]::Escape($_.DisplayVersion), ''  # Strip DisplayVersion
            $_.DisplayName = $_.DisplayName.Trim() # Remove trailing spaces
        }
        $_
    } | Sort-Object DisplayName -Unique

    return $installedSoftware
}

# Function to log changes to a file, ensuring proper logging
function LogChange {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $message"
    
    # Write the log entry to the file
    Add-Content -Path $logFile -Value $logEntry
}

# Get current installed software
$currentSoftware = Get-InstalledSoftware

# Check if the previous state file exists
if (Test-Path $previousStateFile) {
    # Load the previous state
    $previousSoftware = Get-Content $previousStateFile | ConvertFrom-Json

    # Compare current and previous software lists
    $newSoftware = Compare-Object -ReferenceObject $previousSoftware -DifferenceObject $currentSoftware -Property DisplayName -PassThru |
    Where-Object { $_.SideIndicator -eq '=>' }

    $removedSoftware = Compare-Object -ReferenceObject $previousSoftware -DifferenceObject $currentSoftware -Property DisplayName -PassThru |
    Where-Object { $_.SideIndicator -eq '<=' }

    # Report new installs
    if ($newSoftware) {
        Write-Output "New software installed:"
        $newSoftware | ForEach-Object {
            Write-Output " - $($_.DisplayName)"
            LogChange "Installed: $($_.DisplayName)"
        }
    }

    # Report removals
    if ($removedSoftware) {
        Write-Output "The following software(s) were removed:"
        $removedSoftware | ForEach-Object {
            Write-Output " - $($_.DisplayName)"
            LogChange "Removed: $($_.DisplayName)"
        }
    }

    # Save the current state (overwrite the existing file)
    $currentSoftware | ConvertTo-Json | Out-File -FilePath $previousStateFile -Encoding UTF8

    # Exit with status code based on changes
    if ($newSoftware -or $removedSoftware) {
        exit 1
    }
    else {
        Write-Output "No new software installations or removals detected."
        exit 0
    }
}
else {
    # Save the current state if no previous state exists (overwrite if needed)
    $currentSoftware | ConvertTo-Json | Out-File -FilePath $previousStateFile -Encoding UTF8
    LogChange "Initial software inventory saved."
    Write-Output "Initial software inventory saved."
    exit 0
}

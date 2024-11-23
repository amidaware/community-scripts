<#

.SYNOPSIS
    Checks DISM and SFC. Repairs when needed.

.DESCRIPTION
    This is for checking to make sure the backend source files of Windows are in a good state and not corrupted. Also shrinks DISM if features have been removed from windows

.NOTES
    v1.0 11/23/2024 silversword411 Initial release. 
#>

# Perform DISM Health Check
$dismhealth = DISM /Online /Cleanup-Image /ScanHealth

if ($dismhealth -match "The component store is repairable") {
    # Attempt to restore health if repairable
    $dismhealthfix = DISM /Online /Cleanup-Image /RestoreHealth
    if ($dismhealthfix -match "The restore operation completed successfully") {
        Log-Activity -Message "DISM Fixes Successful." -EventName "DISM Health"
        Write-Output "DISM Fixes Performed."
    }
    else {
        Write-Output "DISM RestoreHealth failed. Check logs for details."
    }
}
elseif ($dismhealth -match "No component store corruption detected") {
    Write-Output "DISM Health is good."
}
else {
    Write-Output "DISM ScanHealth encountered an unexpected result. Check logs for details."
}

# DISM Component Store Space Check
$dismspacecheck = DISM /Online /Cleanup-Image /AnalyzeComponentStore

if ($dismspacecheck -match "Component Store Cleanup Recommended : Yes") {
    if ($dismspacecheck -match "Reclaimable Packages : (\d+)") {
        $reclaimablePackages = [int]$Matches[1]
        if ($reclaimablePackages -gt 4) {
            Write-Output "Cleanup needed. Performing cleanup..."
            DISM /Online /Cleanup-Image /StartComponentCleanup
            Log-Activity -Message "DISM Cleanup Performed" -EventName "DISM Cleanup"
        }
        else {
            Write-Output "Cleanup recommended but reclaimable packages are minimal."
        }
    }
    else {
        Write-Output "Cleanup recommended, but reclaimable package count could not be determined."
    }
}
else {
    Write-Output "Cleanup not needed."
}


# SFC
$sfcverify = ($(sfc /verifyonly) -split '' | ? { $_ -and [byte][char]$_ -ne 0 }) -join ''
if ($sfcverify -like "*found integrity violations*") {
    Write-Output("SFC found corrupt files. Fixing.")
    $sfcfix = ($(sfc /scannow) -split '' | ? { $_ -and [byte][char]$_ -ne 0 }) -join ''
    if ($sfcfix -like "*unable to fix*") {
        Rmm-Alert -Category 'SFC' -Body 'SFC fixes failed!'
        Write-Output("SFC was unable to fix the issues.")
    }
    else {
        Write-Output("SFC repair successful.")
        Log-Activity -Message "SFC Fixes Successful!" -EventName "SFC"
    }
}
else {
    Write-Output("SFC is all good.")
}

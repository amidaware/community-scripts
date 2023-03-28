<#
    .SYNOPSIS
    Check Windows activation status
    .DESCRIPTION
    This script checks the Windows activation status by running the "slmgr.vbs" script and returning the results. If the Windows version is activated, the script returns success (exit code 0), otherwise it returns failure (exit code 1).
    .OUTPUTS
    This cmdlet outputs a message indicating whether Windows is activated or not.
    .NOTES
    Version: 1.0 7/17/2021 silversword
#>

$WinVerAct = (cscript /Nologo "C:\Windows\System32\slmgr.vbs" /xpr) -join ''

if ($WinVerAct -like '*Activated*') {
    Write-Output "All looks fine $WinVerAct"
    exit 0
}

else {
    Write-Output "Theres an issue $WinVerAct"
    exit 1
}

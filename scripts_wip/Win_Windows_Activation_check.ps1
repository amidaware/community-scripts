$WinVerAct = (cscript /Nologo "C:\Windows\System32\slmgr.vbs" /xpr) -join ''

if ($WinVerAct -like '*Activated*' -or $WinVerAct -like '*Aktiviert*' -or $WinVerAct -like '*Volumen-Aktivierung*' -or $WinVerAct -like '*Volume Activation*') {
    Write-Output "All looks fine $WinVerAct"
    exit 0
}

else {
    Write-Output "Theres an issue $WinVerAct"
    exit 1
}

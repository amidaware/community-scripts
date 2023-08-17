# Check if OnlineBackup (MSP360) is installed.
$software = "McAfee LiveSafe"
$installed = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
    Get-ItemProperty |
    Select-Object -Property DisplayName, DisplayVersion |
    Where { $_.DisplayName -Match $software }

if ($installed) {
    # Exit success
    Write-Output "$software is installed"
    Write-Output $installed
	$host.SetShouldExit(1)
	Exit
} else {
    # Exit failure to trigger the action
    Write-Output "$software is not installed"
	$host.SetShouldExit(0)
	Exit
}

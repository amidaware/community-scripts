# Get OS version for using later

$caption = (Get-WmiObject -class Win32_OperatingSystem).Caption

if ($caption.ToLower().Contains("server")) {
    Write-Output "server"
}
else {
    Write-Output "workstation"
}
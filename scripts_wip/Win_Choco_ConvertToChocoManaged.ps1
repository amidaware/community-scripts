# Untested script from cleveradmin, please test and fix

$Applist = @('Adobe Acrobat Reader DC', 'Google Chrome')
$InstalledSoftware = Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
foreach ($obj in $InstalledSoftware) {
    if ($obj.GetValue('DisplayName') -in $Applist) {
        $Appname = $obj.GetValue('DisplayName')
        Write-Host "Match $Appname"
    }
    
}
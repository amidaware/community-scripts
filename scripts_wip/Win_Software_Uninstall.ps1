<#
.SYNOPSIS
    Uninstalls a specified application from Windows.

.DESCRIPTION
    This script uninstalls an application from a Windows system. It searches for the application in the system's registry to find its uninstall string and then uses msiexec.exe to perform the uninstallation.

.PARAMETER Application
    The name of the application to be uninstalled. It is a mandatory string parameter.

.EXAMPLE
    -Application "ExampleApp"
    Uninstalls the application named "ExampleApp".

.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2023-11-27

#>

Param(
    [Parameter(Mandatory)]
    [string]$Application
)

Write-Output "Attempting to uninstall $Application"
$Paths = @("HKLM:\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\*",
    "HKLM:\SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\*")
if ($Application -ne "") {
    foreach ($app in Get-ItemProperty $Paths | Where-Object { $_.Displayname -match [regex]::Escape($Application) } | Sort-Object DisplayName) {
        if ($app.UninstallString) {
            Write-Output "Found $Application uninstall string"
            $MsiArguments = $app.UninstallString -Replace "MsiExec.exe ", "" -Replace "/I", "/X"
            Write-Output "Executing msiexec $MsiArguments /quiet /norestart /qn"
            Start-Process -FilePath msiexec.exe -ArgumentList "$MsiArguments /quiet /norestart /qn" -Wait
            Start-Sleep -Seconds 20
            $UninstallTest = (Get-ItemProperty $Paths | Where-object { $_.UninstallString -match [regex]::Escape($Application) }).DisplayName
            Write-Output "Uninstall Test: $UninstallTest"
            If ($UninstallTest) {
                Write-Output "$Application Uninstall Failed"
            }
            else {
                Write-Output "$Application Uninstalled"
            }
        }
        
        break
    }
}
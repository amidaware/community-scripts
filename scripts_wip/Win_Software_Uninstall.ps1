<#
.SYNOPSIS
    Uninstalls a specified application from Windows.

.DESCRIPTION
    This script uninstalls an application from a Windows system. It searches for the 
    application in the system's registry to find its uninstall string and then uses
    msiexec.exe or the apps spec to perform the uninstallation.

.PARAMETER Application
    The name of the application to be uninstalled. It is a mandatory string parameter.

.EXAMPLE
    -Application "ExampleApp"
    -Application "ExampleApp","AnotherApp"
    Uninstalls the application named "ExampleApp".

.NOTES
    Version: 1.0
    Author: redanthrax
    Creation Date: 2023-11-27
    Updated Date: 2024-03-22
#>

Param(
    [string[]]$Application
)

function Win_Software_Uninstall {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [string[]]$Application
    )

    Begin {
        $Apps = @()
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    }

    Process {
        try {
            foreach($app in $Application) {
                Write-Output "Getting $app data"
                if ($null -ne ($Apps | Where-Object { $_.DisplayName -Match [regex]::Escape($app)})) {
                    Write-Output "Found $app in the registry, uninstalling..."
                    $uninstallString = ($Apps | Where-Object { $_.DisplayName -Match [regex]::Escape($app) }).UninstallString
                    if ($uninstallString) {
                        if ($uninstallString.GetType().Name -eq "Object[]") {
                            foreach ($unst in $uninstallString) {
                                $m = [regex]::Match($unst, '')
                                if ($unst -like "*`"*") {
                                    $m = [regex]::Match($unst, '^"([^"]+)"\s*(.*)')
                                }
                                else {
                                    $m = [regex]::Match($unst, '^(.*?)\s(.*)$')
                                }

                                $path = $m.Groups[1].Value
                                $arguments = $m.Groups[2].Value
                                if ($path.ToLower() -like "*msiexec*") {
                                    Write-Output "Executing: $path $arguments /quiet /qn /noreboot"
                                    Start-Process $path -ArgumentList $arguments, "/quiet", "/qn", "/noreboot" -Wait -NoNewWindow
                                }
                                else {
                                    Write-Output "Executing: $path $arguments /x /s /v/qn"
                                    Start-Process $path -ArgumentList $arguments, "/x", "/s", "/v/qn" -Wait -NoNewWindow
                                }
                            }
                        }
                        else {
                            $m = [regex]::Match($uninstallString, '^(\S+)\s(.+)$')
                            $path = $m.Groups[1].Value
                            $arguments = $m.Groups[2].Value
                            if ($path.ToLower() -like "*msiexec*") {
                                $arguments = $arguments -Replace '/I', '/X'
                                Write-Output "Executing: $path $arguments /quiet /qn /noreboot"
                                Start-Process $path -ArgumentList $arguments, "/quiet", "/qn", "/noreboot" -Wait -NoNewWindow
                            }
                            else {
                                Write-Output "Executing: $path $arguments /x /s /v/qn"
                                Start-Process $path -ArgumentList $arguments, "/x", "/s", "/v/qn" -Wait -NoNewWindow
                            }
                        }

                        Write-Output "Validating uninstall complete"
                        $Apps = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
                        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

                        if ($null -eq ($Apps | Where-Object { $_.DisplayName -Match [regex]::Escape($app)})) {
                            Write-Output "$app uninstall verified"
                        }
                        else {
                            Write-Error "Could not uninstall $app"
                        }
                    }
                    else {
                        Write-Output "Did not find uninstall string for $app"
                    }
                }
                else {
                    Write-Output "Did not find $app in the registry"
                }
            }
        }
        Catch {
            Write-Error "Error $($_.Exception)"
        }

    }

    End {
        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-Not(Get-Command 'Win_Software_Uninstall' -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{}
if($Application) {
    $scriptArgs = @{
        Application = $Application
    }
}

Win_Software_Uninstall @scriptArgs
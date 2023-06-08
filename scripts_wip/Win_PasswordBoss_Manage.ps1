<#
.Synopsis
    Write a basic summary of the script.
.DESCRIPTION
    Write a detailed description of the script.
.EXAMPLE
    Example script usage here. Use multiple .EXAMPLE annotation for multi usage.
.INSTRUCTIONS
    Write detailed instructions here for setup/rmm usage.
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 5/42/2023
#>

Param(
    [switch]$Uninstall
)

function Win_PasswordBoss_Manage {
    [CmdletBinding()]
    Param(
        [switch]$Uninstall
    )

    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        If (-not(Get-InstalledModule RunAsUser -ErrorAction SilentlyContinue)) {
            Set-PSRepository PSGallery -InstallationPolicy Trusted
            Install-PackageProvider -Name NuGet -Confirm:$false -Force
            Install-Module RunAsUser -Confirm:$False -Force
        }

        #Do script setup/checks for services/software and folder creation here
        if (-not(Test-Path "$env:Temp\pbpackage")) { New-Item -ItemType Directory -Force -Path "$env:Temp\pbpackage" | Out-Null }
    }

    Process {
        Try {
            #Main Script Process here
            if ($Uninstall) {
                #todo
            }

            if ((Get-ItemPropertyValue -Path "HKLM:\Software\PasswordBoss" -Name "PreInstall" -ErrorAction SilentlyContinue) -eq 'True') {
                Write-Output "PasswordBoss Preinstall already installed."
            }
            else {
                $baseUrl = "https://install.passwordboss.com"
                $preinstall = "PBPreInstaller.exe"
                $vc = "vcredist_2013x86.exe"
                Write-Output "Running preinstall."
                $destination = "$env:Temp\pbpackage\$preinstall"
                Invoke-WebRequest -Uri "$baseUrl/$preinstall" -OutFile $destination
                Start-Process $destination -Wait
                Write-Output "Running VC Redist."
                $destination = "$env:Temp\pbpackage\$vc"
                Invoke-WebRequest -Uri "$baseUrl/$vc" -OutFile $destination
                Start-Process -FilePath $destination -ArgumentList "/install", "/quiet", "/norestart", "/log", "C:\Windows\Logs\Software\VisualC++2013x32-Install.log" -Wait
            }

            Write-Output "Starting user install."
            $block = {
                if (Test-Path -Path "$env:LocalAppData\PasswordBoss\PasswordBoss.exe" -PathType Leaf) {
                    Write-Output "PasswordBoss already installed for user." 
                }
                else {
                    Write-Output "Downloading PasswordBoss..."
                    $baseUrl = "https://install.passwordboss.com"
                    $exe = "Password_Boss.exe"
                    $destination = "$env:Temp\pbpackage\$exe"
                    if (-not(Test-Path "$env:Temp\pbpackage")) { New-Item -ItemType Directory -Force -Path "$env:Temp\pbpackage" | Out-Null }
                    Invoke-WebRequest -Uri "$baseUrl/$exe" -OutFile $destination
                    Write-Output "Installing PasswordBoss as User"
                    Start-Process $destination -ArgumentList "/q2" -Wait
                    Write-Output "Cleaning up."
                    if (Test-Path "$env:Temp\pbpackage") {
                        Remove-Item -Path "$env:Temp\pbpackage" -Recurse -Force
                    }
                }
            }

            Invoke-AsCurrentUser -ScriptBlock $block
            Write-Output "User install complete."
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        if (Test-Path "$env:Temp\pbpackage") {
            Remove-Item -Path "$env:Temp\pbpackage" -Recurse -Force
        }

        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_PasswordBoss_Manage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    Uninstall = $Uninstall
}
 
Win_PasswordBoss_Manage @scriptArgs
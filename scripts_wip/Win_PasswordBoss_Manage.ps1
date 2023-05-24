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
        #Do script setup/checks for services/software and folder creation here
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | Sort-Object { Get-Random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            #Main Script Process here
            if ($Uninstall) {
                #todo
            }

            Write-Output "Starting installation..."
            $source = "https://install.passwordboss.com/Password_Boss.exe"
            $destination = "C:\packages$random\Password_Boss.exe"
            Write-Output "Downloading installer..."
            Invoke-WebRequest -Uri $source -OutFile $destination
            Write-Output "Starting install process..."
            $arguments = @("/b0", "/f", "/q2")
            $process = Start-Process -NoNewWindow -FilePath $destination -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if($timedOut) {
                $process | Stop-Process
                Write-Output "Installed timed out after 300 seconds."
            }
            elseif ($process.ExitCode -ne 0) {
                Write-Output "Install error code: $($process.ExitCode)"
            }
            else {
                Write-Output "Installation complete."
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        #Script cleanup and final checks here
        #Check for last errors and exit
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
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
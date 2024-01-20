<#
.SYNOPSIS
    A script to install or remove the new Teams from Microsoft.
.DESCRIPTION
   Downloads the bootstrap and installs or uninstalls the new Teams. Set new Teams
   as the default in the Teams Admin Center. This will become the default in the future.
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2024-1-18
#>

Param(
    [switch]$Uninstall
)

function Win_Teams_Upgrade {
    [CmdletBinding()]
    Param(
        [switch]$Uninstall
    )

    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { 
            New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null 
        }
    }

    Process {
        Try {
            $destination = "C:\packages$random\teamsbootstrapper.exe"
            $request = @{
                Uri = "https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409"
                OutFile = $destination
            }

            Invoke-WebRequest @request
            $arguments = @("-p")

            if ($Uninstall) {
                Write-Output "Uninstalling new Teams..."
                $arguments = @("-x")
            }
            else {
                Write-Output "Installing new Teams..."
            }

            $options = @{
                NoNewWindow = $true
                FilePath = $destination
                ArgumentList = $arguments
                PassThru = $true
            }

            $process = Start-Process @options
            $timedOut = $null
            $options = @{
                Timeout = 300
                ErrorAction = "SilentlyContinue"
                ErrorVariable = $timedOut
            }

            $process | Wait-Process @options
            if ($timedOut) {
                $process | Stop-Process
                Write-Output "Install timed out after 300 seconds."
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code"
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        Start-Sleep -Seconds 3
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        if($error) {
            Write-Output "Error: $error"
            Exit 1
        }

        Write-Output "Execution complete."
        Exit 0
    }
}

if (-Not(Get-Command 'Win_Teams_Upgrade' -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    Uninstall = $Uninstall
}

Win_Teams_Upgrade @scriptArgs
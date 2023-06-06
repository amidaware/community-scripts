<#
.Synopsis
   Installs Perch Log Shipper
.DESCRIPTION
   Downloads the Perch Log Shipper executable and installs.
   Navigate to Settings > Network > Sensors in the Perch app.
.EXAMPLE
    Win_PerchLogShipper_Install -Token "abc-123-def-456"
.INSTRUCTIONS
    1. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, create the following custom fields: 
        a) PerchToken as type text
    2. In Tactical RMM, Right-click on each client and select Edit. Fill in the PerchToken.
    3. Create the follow script arguments
        a) -Token {{client.PerchToken}}
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2022-04-08
#>

Param(
    [Parameter(Mandatory)]
    [string]$Token,

    [switch]$Uninstall
)

function Win_PerchLogShipper_Install {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$Token,

        [switch]$Uninstall
    )

    Begin {
        $Apps = @()
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        if ($null -ne (Get-Service | Where-Object { $_.DisplayName -Match "perch" }) -and -Not($Uninstall)) {
            Write-Output "Perch already installed."
            Exit 0
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            if ($Uninstall) {
                $uninstallString = ($Apps | Where-Object { $_.DisplayName -Match "Perch Log Shipper" }).UninstallString
                if ($uninstallString) {
                    $msiexec, $args = $uninstallString.Split(" ")
                    Start-Process $msiexec -ArgumentList $args, "/qn" -Wait -NoNewWindow
                    Write-Output "Uninstalled Perch Log Shipper"
                    return
                }
                else {
                    Write-Output "No uninstall string found."
                    Exit 0
                }
            }

            $source = "https://cdn.perchsecurity.com/downloads/perch-log-shipper-latest.exe"
            $destination = "C:\packages$random\perch-log-shipper-latest.exe"
            Invoke-WebRequest -Uri $source -OutFile $destination
            $arguments = @("/qn", "OUTPUT=TOKEN", "VALUE=$Token")
            $process = Start-Process -NoNewWindow -FilePath $destination -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | kill
                Write-Output "Install timed out after 300 seconds."
                Exit 1
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code."
                Exit 1
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
            Exit 1
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_PerchLogShipper_Install' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    Token     = $Token
    Uninstall = $Uninstall
}
 
Win_PerchLogShipper_Install @scriptArgs
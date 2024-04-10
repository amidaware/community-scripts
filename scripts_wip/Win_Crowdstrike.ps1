<#
    .SYNOPSIS
    .DESCRIPTION
    .EXAMPLE
    .NOTES
#>

Param (
    [string]$InstallerUrl,

    [string]$CommunityCID,

    [switch]$Uninstall
)

function Win_Crowdstrike {
    [CmdletBinding(DefaultParameterSetName = 'InstallSet')]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'InstallSet')]
        [string]$InstallerUrl,

        [Parameter(Mandatory = $true, ParameterSetName = 'InstallSet')]
        [string]$CommunityCID,

        [Parameter(Mandatory = $true, ParameterSetName = 'UninstallSet')]
        [switch]$Uninstall
    )

    Begin {
        $Apps = @()
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        if ($null -ne ($Apps | Where-Object { $_.DisplayName -Match "CrowdStrike" }) -and -Not($Uninstall)) {
            Write-Output "CrowdStrike already installed."
            Exit 0
        }

        if ($Uninstall -and $null -eq ($Apps | Where-Object { $_.DisplayName -Match "CrowdStrike" })) {
            Write-Output "CrowdStrike already uninstalled"
            Exit 0
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | Sort-Object { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            if ($Uninstall) {
                Write-Output "Uninstalling CrowdStrike"
                $uninstallString = ($Apps | Where-Object { $_.DisplayName -Match "CrowdStrike" }).UninstallString
                foreach ($unstring in $uninstallString) {
                    if ($unstring -Match "msiexec") {
                        $unst = $unstring -Split " "
                        $unst[1] = $unst[1] -Replace '/I', '/X'
                        Start-Process $unst[0] -ArgumentList $unst[1], "/quiet", "/qn", "/noreboot" -Wait -NoNewWindow
                        Write-Output "Uninstalled CrowdStrike resource"
                    }
                    elseif ($unstring -Match "exe") {
                        $unstring = "$unstring /quiet"
                        $pattern = '".*?"'
                        $matches = [regex]::Matches($unstring, $pattern)
                        $run = $matches.value
                        Start-Process $run -ArgumentList "/uninstall", "/quiet" -Wait -NoNewWindow
                        Write-Output "Uninstalled CrowdStrike resource"
                    }
                }

                Write-Output "Uninstall complete."
                return
            }

            Write-Output "Starting installation..."
            $dest = "C:\packages$random\WindowsSensor.exe"
            Write-Output "Downloading file..."
            Invoke-WebRequest -Uri $InstallerUrl -OutFile $dest
            $arguments = @("/install", "/quiet", "/norestart", "CID=$CommunityCID")
            Write-Output "Starting install file..."
            $process = Start-Process -NoNewWindow -FilePath $dest -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 500 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | Stop-Process
                Write-Output "Install timed out after 500 seconds."
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code."
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        if ($error) {
            Exit 1
        }

        Write-Output "Script complete."
        Exit 0
    }
}

if (-not(Get-Command 'Win_Crowdstrike' -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{}

if ($InstallerUrl) {
    $scriptArgs = @{
        InstallerUrl = $InstallerUrl
        CommunityCID = $CommunityCID
    }
}

if ($Uninstall) {
    $scriptArgs = @{
        Uninstall = $Uninstall
    }
}

Win_Crowdstrike @scriptArgs
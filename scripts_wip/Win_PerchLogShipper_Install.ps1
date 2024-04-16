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
   Version: 1.1
   Author: redanthrax
   Creation Date: 2022-04-08
   Update Date: 2024-04-16
#>

Param(
    [string]$Token,

    [string]$LatestVersion = "2023.05.12",

    [switch]$Uninstall
)

function Compare-SoftwareVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version1,

        [Parameter(Mandatory = $true)]
        [string]$Version2
    )

    # Split the version strings into individual parts
    $versionParts1 = $Version1 -split '\.'
    $versionParts2 = $Version2 -split '\.'

    # Get the minimum number of parts between the two versions
    $minParts = [Math]::Min($versionParts1.Count, $versionParts2.Count)

    # Compare the version parts
    for ($i = 0; $i -lt $minParts; $i++) {
        $part1 = [int]$versionParts1[$i]
        $part2 = [int]$versionParts2[$i]

        if ($part1 -gt $part2) {
            return $true
        }
        elseif ($part1 -lt $part2) {
            return $false
        }
    }

    # If all parts are equal, check the length of the version strings
    if ($versionParts1.Count -gt $versionParts2.Count) {
        # Check the additional part in Version1
        $additionalPart = $versionParts1[$minParts..($versionParts1.Count - 1)] -join '.'
        return ![string]::IsNullOrEmpty($additionalPart)
    }
    elseif ($versionParts1.Count -lt $versionParts2.Count) {
        # Check the additional part in Version2
        $additionalPart = $versionParts2[$minParts..($versionParts2.Count - 1)] -join '.'
        return [string]::IsNullOrEmpty($additionalPart)
    }

    return $true
}

function Win_PerchLogShipper_Install {
    [CmdletBinding(DefaultParameterSetName = "InstallSet")]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = "InstallSet")]
        [string]$Token,

        [string]$LatestVersion,

        [Parameter(Mandatory = $true, ParameterSetName = "UninstallSet")]
        [switch]$Uninstall
    )

    Begin {
        $Upgrade = $false
        $Apps = @()
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        if ($null -ne (Get-Service | Where-Object { $_.DisplayName -Match "perch" }) -and -Not($Uninstall)) {
            $perch = $Apps | Where-Object { $_.DisplayName -Match "perch"}
            if (Compare-SoftwareVersion $perch.DisplayVersion $LatestVersion) {
                Write-Output "Perch $($perch.DisplayVersion) already installed."
                Exit 0
            }
            else {
                $Upgrade = $true
            }
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

            if ($Upgrade) {
                Write-Output "Attempting upgrade of Perch Log Shipper"
            }
            else {
                Write-Output "Installing Perch log shipper"
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

            if ($Upgrade) {
                Write-Output "Perch log shipper upgraded"
            }
            else {
                Write-Output "Perch log shipper installed"
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

        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_PerchLogShipper_Install' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{}
if ($Token) {
    $scriptArgs = @{
        Token = $Token
        LatestVersion = $LatestVersion
    }
}
if ($Uninstall) {
    $scriptArgs = @{
        Uninstall = $Uninstall
    }
}
 
Win_PerchLogShipper_Install @scriptArgs
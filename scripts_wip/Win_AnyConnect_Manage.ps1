<#
.Synopsis
    Installs the Cisco Meraki AnyConnect Client.
.Description
    Downloads the AnyConnect client from the specified URL and installs.
.EXAMPLE
    Win_AnyConnect_Manage -Download http://download.file.com/anyconnect.zip
.INSTRUCTIONS
    1. Save the AnyConnect client download zip to an accessible location.
    2. Create a custom field for the download.
    3. Reference the download for the script.
.NOTES
    Version: 1.0
    Author: redanthrax
    Creation Date: 2023-03-02
#>

Param(
    [Parameter(Mandatory)]
    [string]$Download
)

function Win_AnyConnect_Manage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$Download
    )

    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            Write-Output "Starting installation."
            $destination = "C:\packages$random\cisco-secure-client-win-predeploy-k9.zip"
            Write-Output "Downloading file."
            Invoke-WebRequest -Uri $Download -OutFile $destination
            Write-Output "Extracting archive."
            Expand-Archive -LiteralPath $destination -DestinationPath "C:\packages$random"
            $coreInstall = Get-ChildItem "C:\packages$random\" | Where-Object { $_.Name -Match "core" }
            $arguments = @("/package $($coreInstall.VersionInfo.FileName) /norestart /passive PRE_DEPLOY_DISABLE_VPN=0 /qn /quiet")
            Write-Output "Installing vpn core."
            $process = Start-Process -NoNewWindow "msiexec.exe" -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | kill
                throw "Installed timed out after 300 seconds."
            }
            if ($process.ExitCode -ne 0) {
                throw "Install error code: $($process.ExitCode)"
            }


            $sblInstall = Get-ChildItem "C:\packages$random\" | Where-Object { $_.Name -Match "sbl" }
            $arguments = @("/package $($sblInstall.VersionInfo.FileName) /norestart /passive /qn /quiet")
            $process = Start-Process -NoNewWindow "msiexec.exe" -ArgumentList $arguments -PassThru
            $timedOut = $null
            Write-Output "Installing vpn sbl."
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | kill
                throw "Installed timed out after 300 seconds."
            }
            if ($process.ExitCode -ne 0) {
                throw "Install error code: $($process.ExitCode)"
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

        Write-Output "Installation complete."
        Exit 0
    }
}

if (-not(Get-Command 'Win_AnyConnect_Manage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    Download = $Download
}

Win_AnyConnect_Manage @scriptArgs

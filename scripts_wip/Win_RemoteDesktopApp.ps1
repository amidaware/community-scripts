<#
    .SYNOPSIS
        Install Remote Desktop App
    .DESCRIPTION
        This script is used to install the Remote Desktop App
        from a direct link at Microsoft. This is the app required
        for an Azure Virtual Desktop environment.
    .EXAMPLE
        Win_RemoteDesktopApp
    .EXAMPLE
        Win_RemoteDesktopApp -ShowLog
    .EXAMPLE
        Win_RemoteDesktopApp -Timeout 600
    .EXAMPLE
        Win_RemoteDesktopApp -ShowLog -Timeout 600
    .NOTES
        Version: 0.0.1
        Author: redanthrax
        Creation Date: 11/14/2023
#>

Param(
    $Timeout = 300,
    [switch]$ShowLog
)

$dir = "$env:AppData\remoteapp"

function Win_RemoteDesktopApp {
    [CmdletBinding()]
    Param(
        $Timeout = 300,
        [switch]$ShowLog
    )

    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if (-not(Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path "$env:AppData\remoteapp" | Out-Null
        }
    }

    Process {
        Try {
            Write-Output "Downloading Remote App installation..."
            $source = "https://go.microsoft.com/fwlink/?linkid=2139369"
            $destination = "$dir\RemoteDesktop.msi"
            Invoke-WebRequest -Uri $source -OutFile $destination
            Write-Output "File download complete. Starting install with $Timeout second timeout..."
            $arguments = @("/i $destination", "/quiet", "/lv $dir\install.log")
            $process = Start-Process -NoNewWindow "msiexec.exe" -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout $Timeout -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | Stop-Process
                Write-Error "Installed timed out after $Timeout seconds." -ErrorAction SilentlyContinue
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Error "Install error code: $code" -ErrorAction SilentlyContinue
            }

            Write-Output "Creating shortcut."
            New-item -ItemType Directory -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\RemoteApp" | Out-Null
            $WshShell = New-Object -ComObject WScript.Shell
            $shortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\RemoteApp\Remote Desktop App.lnk"
            $Shortcut = $WshShell.CreateShortcut($shortcutPath)
            $target = "C:\Program Files\Remote Desktop\msrdcw.exe"
            $Shortcut.TargetPath = $target
            $description = "Remote Desktop App"
            $Shortcut.Description = $description
            $workingdirectory = (Get-ChildItem $target).DirectoryName
            $shortcut.WorkingDirectory = $workingdirectory
            $Shortcut.Save()
        }
        Catch {
            $exception = $_.Exception
            Write-Error "Error: $exception" -ErrorAction SilentlyContinue
        }
    }

    End {
        if ($ShowLog) {
            Write-Output "===Install Log==="
            Get-Content "$dir\install.log"
        }

        if (Test-Path $dir) {
            Remove-Item -Path $dir -Recurse -Force
        }

        if ($Error) {
            foreach ($err in $Error) {
                Write-Output $err
            }

            Exit 1
        }

        Write-Output "Installation complete."
        Exit 0
    }
}

if (-not(Get-Command 'Win_RemoteDesktopApp'  -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    Timeout = $Timeout
    ShowLog = $ShowLog
}

Win_RemoteDesktopApp @scriptArgs
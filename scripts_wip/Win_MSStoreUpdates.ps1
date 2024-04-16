<#
.Synopsis
    Sets the MS Store Updates setting
.DESCRIPTION
    Toggles auto updates in the MS Store.
    Use the -Enabled parameter to enable and omit the parameter to disable.
.NOTES
    Version: 1.0
    Author: redanthrax
    Creation Date: 2024-04-16
#>

Param(
    [switch]$Enabled
)

function Win_MSStoreUpdates {
    [CmdletBinding()]
    Param(
        [switch]$Enabled
    )

    Begin {
        $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate"
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }

        if ($Enabled) {
            Set-ItemProperty -Path $path -Name "AutoDownload" -Value 4 -Type DWord | Out-Null
            Write-Output "Enabled MS Store Auto Updates"
        }
        else {
            Set-ItemProperty -Path $path -Name "AutoDownload" -Value 2 -Type DWord | Out-Null
            Write-Output "Disabled MS Store Auto Updates"
        }
    }

    Process {
        Try {

        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command "Win_MSStoreUpdates" -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    Enabled = $Enabled
}

Win_MSStoreUpdates @scriptArgs
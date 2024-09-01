# manage_ipv6.ps1

param (
    [string[]]$Command
)

function Show-Help {
    Write-Host "IPv6 Management Script"
    Write-Host "Usage:"
    Write-Host "  Enable              : Enables IPv6."
    Write-Host "  Disable             : Disables IPv6."
    Write-Host "  Info                : Shows the current IPv6 configuration."
}

function Is-IPv6Enabled {
    $bindings = Get-NetAdapterBinding -ComponentID ms_tcpip6 | Where-Object { $_.Enabled -eq $true }
    return $bindings.Count -gt 0
}

function Enable-IPv6 {
    Write-Host "Preparing to enable IPv6..."
    if (Is-IPv6Enabled) {
        Write-Host "IPv6 is already enabled on all network adapters."
    } else {
        Write-Host "Sending command: Enable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip6"
        try {
            Get-NetAdapter | ForEach-Object {
                Enable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6
            }
            Write-Host "IPv6 has been enabled on all network adapters."
        } catch {
            Write-Host "Error: Unable to enable IPv6. Please ensure the script is running with administrative privileges."
        }
    }
}

function Disable-IPv6 {
    Write-Host "Preparing to disable IPv6..."
    if (-not (Is-IPv6Enabled)) {
        Write-Host "IPv6 is already disabled on all network adapters."
    } else {
        Write-Host "Sending command: Disable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip6"
        try {
            Get-NetAdapter | ForEach-Object {
                Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6
            }
            Write-Host "IPv6 has been disabled on all network adapters."
        } catch {
            Write-Host "Error: Unable to disable IPv6. Please ensure the script is running with administrative privileges."
        }
    }
}

function Show-IPv6Info {
    Write-Host "Sending command: Get-NetIPConfiguration | Select-Object -Property IPv6Address, InterfaceAlias"
    try {
        $ipv6Info = Get-NetIPConfiguration | Select-Object -Property IPv6Address, InterfaceAlias
        if ($ipv6Info) {
            Write-Host "IPv6 Information:"
            $ipv6Info | Format-Table -AutoSize
        } else {
            Write-Host "No IPv6 information found. IPv6 may be disabled or not configured."
        }
    } catch {
        Write-Host "Error: Unable to retrieve IPv6 information. This may occur if IPv6 is disabled or if PowerShell commands are restricted."
    }
}

# Check if no arguments or multiple arguments are passed
if ($Command.Count -eq 0) {
    Write-Host "No argument detected."
    Show-Help
    exit
} elseif ($Command.Count -gt 1) {
    Write-Host "Error: Multiple arguments detected. Please use only one argument at a time."
    Show-Help
    exit
}

# Normalize argument case and handle command
$Command = $Command[0].ToLower()

# Main logic
switch ($Command) {
    "enable" {
        Enable-IPv6
    }
    "disable" {
        Disable-IPv6
    }
    "info" {
        Show-IPv6Info
    }
    default {
        Write-Host "'$Command' is not a valid argument, see below for all valid arguments."
        Show-Help
    }
}
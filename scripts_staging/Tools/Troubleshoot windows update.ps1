<#
.SYNOPSIS
    This script troubleshoots common issues related to fetching Windows updates, including checking local configuration for WSUS server settings.

.DESCRIPTION
    The script checks network connectivity, DNS resolution, the status of key services, the PSWindowsUpdate module, 
    Windows Update logs, and other important settings that could be preventing the retrieval of Windows updates. It also checks
    whether a WSUS server is configured locally.

.NOTES
    Author: SAN
    Date: 25.03.2025
    #public
    Dependencies: 
        PSWindowsUpdate module

.CHANGELOG
    SAN 25.03.2025 initial release
#>

function Test-NetworkConnectivity {
    $url = "www.microsoft.com"
    Write-Host "Checking network connectivity to $url..."
    $pingResult = Test-Connection -ComputerName $url -Count 1 -Quiet
    if (-not $pingResult) {
        Write-Host "KO: No network connectivity to $url. Please check your internet connection."
        return $false
    }
    Write-Host "OK: Network connectivity to $url is successful."
    return $true
}

function Test-WindowsUpdateService {
    Write-Host "Checking Windows Update service status..."
    $service = Get-Service wuauserv
    if ($service.Status -ne 'Running') {
        Write-Host "KO: The Windows Update service (wuauserv) is not running. Attempting to start it..."
        try {
            Start-Service wuauserv
            Write-Host "OK: Windows Update service started successfully."
        } catch {
            Write-Host "KO: Failed to start Windows Update service: $_"
            return $false
        }
    } else {
        Write-Host "OK: Windows Update service is running."
    }
    return $true
}

function Test-PSWindowsUpdateModule {
    Write-Host "Checking PSWindowsUpdate module installation..."
    if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
        Write-Host "OK: PSWindowsUpdate module is installed."
        return $true
    } else {
        Write-Host "KO: PSWindowsUpdate module is not installed. Please install it using 'Install-Module PSWindowsUpdate'."
        return $false
    }
}

function Test-DNSResolution {
    Write-Host "Checking DNS resolution for update servers..."
    try {
        $dnsCheck = Resolve-DnsName "download.windowsupdate.com"
        Write-Host "OK: DNS resolution for Windows Update servers is working."
        return $true
    } catch {
        Write-Host "KO: DNS resolution failed for Windows Update servers. Please check your DNS settings."
        return $false
    }
}

function Check-WindowsUpdateAgentVersion {
    Write-Host "Checking Windows Update Agent version..."
    try {
        $wuaAgentVersion = (Get-Command "C:\Windows\System32\wuauclt.exe").FileVersionInfo.FileVersion
        Write-Host "OK: Windows Update Agent version is $wuaAgentVersion."
        return $true
    } catch {
        Write-Host "KO: Could not retrieve Windows Update Agent version. Please ensure the file exists."
        return $false
    }
}

function Check-PendingReboot {
    Write-Host "Checking for pending reboot..."
    $rebootPending = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if ($rebootPending) {
        Write-Host "KO: There is a pending reboot. Please restart the machine and try again."
        return $false
    }
    Write-Host "OK: No pending reboot."
    return $true
}

function Check-WindowsUpdateLogs {
    Write-Host "Checking Windows Update logs for errors..."
    $logPath = "C:\Windows\WindowsUpdate.log"
    if (Test-Path $logPath) {
        $logContent = Get-Content $logPath -Tail 50
        if ($logContent -match "error|failed") {
            Write-Host "KO: Found errors in the Windows Update log:"
            $logContent | Select-String "error|failed" | Format-Table -AutoSize
        } else {
            Write-Host "OK: No errors found in the recent Windows Update logs."
        }
    } else {
        Write-Host "KO: Windows Update log file not found at $logPath."
        return $false
    }
    return $true
}

function Check-WindowsUpdateEventLogs {
    Write-Host "Checking for Windows Update related errors in the Event Log..."
    $events = Get-WinEvent -LogName "System" | Where-Object { $_.Message -match "update|windowsupdate" } | Select-Object -First 5
    if ($events) {
        Write-Host "KO: Found the following Windows Update related event(s):"
        $events | Format-Table -Property TimeCreated, Message -AutoSize
    } else {
        Write-Host "OK: No Windows Update related events found in the Event Log."
    }
}

function Check-WSUSServerConfiguration {
    Write-Host "Checking if WSUS server is configured..."
    $wsusServer = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" -Name WUServer -ErrorAction SilentlyContinue
    if ($wsusServer) {
        Write-Host "INFO: WSUS server configured with address: $($wsusServer.WUServer)."
    } else {
        Write-Host "OK: No WSUS server is configured."
    }
}

Write-Host "Starting troubleshooting script..."

if (-not (Test-NetworkConnectivity)) {
    exit 1
}

if (-not (Test-WindowsUpdateService)) {
    exit 1
}

if (-not (Test-PSWindowsUpdateModule)) {
    exit 1
}

if (-not (Test-DNSResolution)) {
    exit 1
}

if (-not (Check-WindowsUpdateAgentVersion)) {
    exit 1
}

if (-not (Check-PendingReboot)) {
    exit 1
}

if (-not (Check-WindowsUpdateLogs)) {
    exit 1
}

Check-WSUSServerConfiguration
Check-WindowsUpdateEventLogs

Write-Host "All checks completed. If any issues were detected, follow the suggested actions."

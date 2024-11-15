<#
.SYNOPSIS
   Checks for all problems related to TRMM and Mesh Agent.

.DESCRIPTION
   This script checks for the presence of Mesh Agent service, folder, and executable file. If any of these components are missing, it returns an error code of 1.

.PARAMETER debug
   Switch parameter to enable debug output.

.NOTES
   Version: 1.0 Created 6/6/2023 by silversword411
   v1.2 5/15/2024 Adding default NIC info, TRMM registry data
   v1.3 5/15/2024 Adding mesh server URL discovery, connection check to mesh and API, and checking for files and services
   v1.4 5/15/2024 Rework and simplify. Write out logfile
   v1.5 6/21/2024 Adding trmm agent to Check-Memorysize
   v1.6 8/26/2024 checking mesh for CF proxy
#>

param(
    [String] $procname = "meshagent,tacticalrmm",
    [Int] $warnwhenovermemsize = 100000000,
    [switch]$debug
)

if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
}

$logfile = "$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')-trmmagenttroubleshooting.log"
Start-Transcript -Path $logfile -Append

function Get-CloudflareIPRanges {
    $ipv4Url = "https://www.cloudflare.com/ips-v4"
    $ipv6Url = "https://www.cloudflare.com/ips-v6"
    
    try {
        if ($Debug) { Write-Output "Downloading Cloudflare IPv4 ranges..." }
        $ipv4Ranges = Invoke-WebRequest -Uri $ipv4Url -UseBasicParsing | Select-Object -ExpandProperty Content
        
        if ($Debug) { Write-Output "Downloading Cloudflare IPv6 ranges..." }
        $ipv6Ranges = Invoke-WebRequest -Uri $ipv6Url -UseBasicParsing | Select-Object -ExpandProperty Content
        
        $global:CloudflareIPRanges = @()
        $global:CloudflareIPRanges += $ipv4Ranges -split "`n"
        $global:CloudflareIPRanges += $ipv6Ranges -split "`n"

        if ($Debug) { Write-Output "Cloudflare IP ranges downloaded successfully." }
    }
    catch {
        Write-Output "Failed to download Cloudflare IP ranges. Please check your internet connection."
        $global:CloudflareIPRanges = $null
    }
}

function ConvertTo-IPv4Integer {
    param ([string]$ip)
    
    $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
    [Array]::Reverse($ipBytes)  # Convert to little-endian format
    return [BitConverter]::ToUInt32($ipBytes, 0)
}

function Test-IPv4InRange {
    param (
        [string]$ip,
        [string]$cidr
    )

    # Split the CIDR notation
    $parts = $cidr -split '/'
    $baseIP = $parts[0]
    $subnetMask = [int]$parts[1]

    # Convert IP and base IP to 32-bit integers
    $ipInt = ConvertTo-IPv4Integer -ip $ip
    $baseIPInt = ConvertTo-IPv4Integer -ip $baseIP

    # Create the mask as a 32-bit unsigned integer
    $mask = 0xFFFFFFFF -shl (32 - $subnetMask)

    # Compare the masked IP with the base IP
    return (($ipInt -band $mask) -eq ($baseIPInt -band $mask))
}

function Test-CloudflareProxy {
    if ($Debug) { Write-Output "Starting Cloudflare IP range retrieval..." }
    Get-CloudflareIPRanges

    if ($Debug) { Write-Output "Resolving IP addresses for $global:MeshServerAddress..." }

    try {
        $resolvedIPs = [System.Net.Dns]::GetHostAddresses($global:MeshServerAddress)

        if ($resolvedIPs.Count -eq 0) {
            Write-Output "No IP addresses resolved for $global:MeshServerAddress."
            return
        }
        else {
            if ($Debug) {
                Write-Output "Resolved IP addresses:"
                foreach ($ip in $resolvedIPs) {
                    Write-Output " - $($ip.IPAddressToString)"
                }
            }
        }
    }
    catch {
        Write-Output "Failed to resolve IP addresses for $global:MeshServerAddress. Error: $_"
        return
    }

    $cloudflareDetected = $false
    $matchedIP = $null

    foreach ($ip in $resolvedIPs) {
        if ($ip.AddressFamily -eq "InterNetwork") {
            # Only IPv4
            foreach ($range in $global:CloudflareIPRanges) {
                if ($Debug) { Write-Output "Checking if IP $($ip.IPAddressToString) is in range $range..." }
                if (Test-IPv4InRange -ip $ip.IPAddressToString -cidr $range) {
                    $cloudflareDetected = $true
                    $matchedIP = $ip.IPAddressToString
                    break
                }
            }
        }
        if ($cloudflareDetected) { break }
    }

    if ($cloudflareDetected) {
        if ($Debug) {
            Write-Output "The IP address $matchedIP is within Cloudflare ranges."
        }
        else {
            Write-Output "WARNING: $global:MeshServerAddress is using Cloudflare proxy IP $matchedIP."
        }
    }
    else {
        $notMatchedIP = $resolvedIPs | Where-Object { $_.AddressFamily -eq "InterNetwork" } | Select-Object -First 1
        if ($Debug) {
            Write-Output "None of the resolved IPs are within Cloudflare ranges."
        }
        else {
            Write-Output "The MeshServerAddress $global:MeshServerAddress is NOT using Cloudflare (IP $($notMatchedIP.IPAddressToString))."
        }
    }
}

function Check-MemorySize {
    if (!($procname)) {
        Write-Output "No procname defined, and it is required. Exiting"
        Stop-Transcript
        Exit 1
    }

    if (!($warnwhenovermemsize)) {
        Write-Output "No warnwhenovermemsize defined, and it is required. Exiting"
        Stop-Transcript
        Exit 1
    }

    Write-Debug "Warn when Memsize exceeds: $warnwhenovermemsize"
    Write-Debug "#####"

    $procnameList = $procname -split ','

    foreach ($proc in $procnameList) {
        $proc = $proc.Trim()
        Write-Debug "Checking process: $proc"

        $proc_pid = (get-process -Name $proc -ErrorAction SilentlyContinue).Id

        if ($null -eq $proc_pid) {
            Write-Output "Process $proc not found."
            continue
        }

        $Processes = Get-WmiObject -Query "SELECT * FROM Win32_PerfFormattedData_PerfProc_Process WHERE IDProcess=$proc_pid"

        foreach ($Process in $Processes) {
            $WS_MB = [math]::Round($Process.WorkingSetPrivate / 1MB, 2)

            if ($Process.WorkingSetPrivate -gt $warnwhenovermemsize) {
                Write-Output "WARNING: $($WS_MB)MB: $($proc) has high memory usage"
                Restart-service -name "Mesh Agent"
                Stop-Transcript
                Exit 1
            }
            else {
                Write-Output "$($WS_MB)MB: $($proc) is below the expected memory usage"
            }
        }
    }
}


function Check-ForMeshComponents {
    $serviceName = "Mesh Agent"
    $ErrorCount = 0

    if (!(Get-Service $serviceName -ErrorAction SilentlyContinue)) { 
        Write-Output "Mesh Agent Service Missing"
        $ErrorCount += 1
    }
    else {
        Write-Output "Mesh Agent Service Found"
    }

    if (!(Test-Path "c:\Program Files\Mesh Agent")) {
        Write-Output "Mesh Agent Folder missing"
        $ErrorCount += 1
    }
    else {
        Write-Output "Mesh Agent Folder exists"
    }

    if (!(Test-Path "c:\Program Files\Mesh Agent\MeshAgent.exe")) {
        Write-Output "Mesh Agent executable missing"
        $ErrorCount += 1
    }
    else {
        Write-Output "Mesh Agent executable exists"
    }

    if ($ErrorCount -ne 0) {
        Stop-Transcript
        exit 1
    }
}

function Get-DefaultNetworkAdapter {
    $networkConfigs = Get-NetIPConfiguration
    $defaultRoutes = Get-NetRoute -DestinationPrefix '0.0.0.0/0'

    if ($defaultRoutes.Count -eq 0) {
        Write-Output "No default route found."
        return
    }

    $defaultConfigs = @()
    foreach ($route in $defaultRoutes) {
        $config = $networkConfigs | Where-Object { $_.InterfaceIndex -eq $route.InterfaceIndex }
        if ($config) {
            $defaultConfigs += [PSCustomObject]@{
                InterfaceAlias  = $config.InterfaceAlias
                InterfaceMetric = $route.RouteMetric + $config.InterfaceMetric
                IPv4Address     = $config.IPv4Address.IPAddress
                DefaultGateway  = $route.NextHop
                DnsServers      = $config.DnsServer.ServerAddresses
            }
        }
    }

    if ($defaultConfigs.Count -eq 0) {
        Write-Output "No default network adapter found."
        return
    }

    $defaultConfig = $defaultConfigs | Sort-Object { $_.InterfaceMetric } | Select-Object -First 1

    Write-Output "Default Network Adapter:"
    Write-Output "Name                 : $($defaultConfig.InterfaceAlias)"
    Write-Output "IP Address           : $($defaultConfig.IPv4Address)"
    Write-Output "Default Gateway      : $($defaultConfig.DefaultGateway)"
    Write-Output "DNS Servers          : $($defaultConfig.DnsServers -join ', ')"
}

function Get-TacticalRMMData {
    $registryPath = "HKLM:\SOFTWARE\TacticalRMM"
    $global:ApiURL = $null
    
    if (Test-Path $registryPath) {
        $registryData = Get-ItemProperty -Path $registryPath
        
        foreach ($property in $registryData.PSObject.Properties) {
            if ($property.Name -eq "AgentID" -or $property.Name -eq "Token") {
                $truncatedValue = $property.Value.Substring(0, [Math]::Min(5, $property.Value.Length)) + "-snipped"
                Write-Output "$($property.Name): $truncatedValue"
            }
            elseif ($property.Name -eq "ApiURL") {
                $global:ApiURL = $property.Value
                Write-Output "$($property.Name): $($property.Value)"
            }
            else {
                Write-Output "$($property.Name): $($property.Value)"
            }
        }
    }
    else {
        Write-Output "The registry key '$registryPath' does not exist."
    }
}

$global:MeshServerAddress = $null

function Get-MeshServer {
    param (
        [string]$filePath = "C:\Program Files\Mesh Agent\MeshAgent.msh"
    )
    $global:MeshServerAddress = $null

    if (Test-Path $filePath) {
        $content = Get-Content -Path $filePath
        $meshServerLine = $content | Select-String -Pattern "MeshServer"

        if ($meshServerLine) {
            $meshServer = $meshServerLine -replace "MeshServer=wss://", "" -replace ":.*", ""
            $global:MeshServerAddress = $meshServer
        }
        else {
            Write-Output "MeshServer not found in the file."
        }
    }
    else {
        Write-Output "File not found: $filePath"
    }
}

function Test-ServerConnections {
    if ($global:MeshServerAddress) {
        Write-Output "Pinging MeshServerAddress: $global:MeshServerAddress"
        Test-Connection -ComputerName $global:MeshServerAddress -Count 2 | Format-Table -AutoSize
    }
    else {
        Write-Output "MeshServerAddress is not set."
    }

    if ($global:ApiURL) {
        try {
            if ($global:ApiURL -notmatch "^[a-zA-Z][a-zA-Z0-9+.-]*://") {
                $global:ApiURL = "http://$global:ApiURL"
            }

            $uri = [System.Uri]::new($global:ApiURL)
            $hostname = $uri.Host
            Write-Output "Pinging ApiURL: $hostname"
            Test-Connection -ComputerName $hostname -Count 2 | Format-Table -AutoSize
        }
        catch {
            Write-Output "Failed to parse ApiURL: $global:ApiURL"
            Write-Output "Error: $_"
        }
    }
    else {
        Write-Output "ApiURL is not set."
    }
}

function Check-ServicesAndFiles {
    param (
        [string]$MeshAgentPath = "C:\Program Files\Mesh Agent\MeshAgent.exe",
        [string]$TacticalRmmPath = "C:\Program Files\TacticalAgent\tacticalrmm.exe",
        [string]$MeshAgentService = "Mesh Agent",
        [string]$TacticalRmmService = "tacticalrmm"
    )

    function Test-File {
        param (
            [string]$FilePath
        )
        return Test-Path -Path $FilePath
    }

    function Test-Service {
        param (
            [string]$ServiceName
        )
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            Write-Output "PROBLEM: $ServiceName service does not exist."
            return $false
        }
        elseif ($service.Status -ne 'Running') {
            Write-Output "PROBLEM: $ServiceName service is not running. Attempting to start..."
            Start-Service -Name $ServiceName
            if ($?) {
                Write-Output "OK: $ServiceName service started successfully."
                return $true
            }
            else {
                Write-Output "PROBLEM: Failed to start $ServiceName service."
                return $false
            }
        }
        else {
            Write-Output "OK: $ServiceName service is running."
            return $true
        }
    }

    if (Test-File -FilePath $MeshAgentPath) {
        Write-Output "OK: MeshAgent.exe file exists."
    }
    else {
        Write-Output "PROBLEM: MeshAgent.exe file does not exist."
    }

    if (Test-File -FilePath $TacticalRmmPath) {
        Write-Output "OK: tacticalrmm.exe file exists."
    }
    else {
        Write-Output "PROBLEM: tacticalrmm.exe file does not exist."
    }

    if (Test-Service -ServiceName $MeshAgentService) {
        Write-Output "OK: $MeshAgentService service is verified."
    }
    else {
        Write-Output "PROBLEM: $MeshAgentService service verification failed."
    }

    if (Test-Service -ServiceName $TacticalRmmService) {
        Write-Output "OK: $TacticalRmmService service is verified."
    }
    else {
        Write-Output "PROBLEM: $TacticalRmmService service verification failed."
    }
}

Write-Output "******************** TRMM Registry Data ***********************"
Get-TacticalRMMData
Write-Output ""
Get-MeshServer

Write-Output ""
Write-Output "********************** Usable Variables ***********************"
Write-Output "Global MeshServerAddress: $global:MeshServerAddress"
Write-Output "Global ApiURL: $global:ApiURL"
Write-Output ""

Write-Output "**************** Check for files and services *****************"
Check-ServicesAndFiles
Write-Output ""

Write-Output "************************ Default NIC *************************"
Get-DefaultNetworkAdapter
Write-Output ""

Write-Output "************ Test Connectivity to Mesh and TRMM ***************"
Test-ServerConnections
Write-Output ""

Write-Output "************ Checking if MeshServer is using Cloudflare *******"
Test-CloudflareProxy
Write-Output ""

Write-Output "******************* Checking Mesh Agent ***********************"
Check-ForMeshComponents
Write-Output ""

Write-Output "********************* Mesh Memory Size ************************"
Check-MemorySize

Stop-Transcript
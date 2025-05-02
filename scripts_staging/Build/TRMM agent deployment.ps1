<#
.SYNOPSIS
    Checks for connectivity to the rmm, when functional installs Tactical RMM.

.DESCRIPTION
    This script is made to be packaged into a standard ISO and run with or after sysprep and not run from the RMM itself.
    It syncronise the system time to avoid SSL issues, checks for connectivity to 443 of the rmm server, 
    installs Tactical RMM when the network link is up. (retries every 30 seconds)
    If Windows Defender is active, it adds exclusions for Tactical RMM-related paths.
    The log are optionals


.NOTES
    Author: SAN
    Date: 01.10.2024
    #public

.EXEMPLE
    $DeploymentURL = "https://api-rmm-xxxxxxx.xxxxxxxx.xxx/clients/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/deploy/"

.CHANGELOG
    SAN 02.05.25 Cleaned the code for publication and removed sensitive data
    SAN 02.05.25 Use only the domain of the deployement url for the network check, changed to a json query rather than tcp check, added optional max tires and lots of other tweaks

.TODO

#>

$DeploymentURL   = "" # Provide Deployment URL

$logDirectory    = "" # Provide OPTIONAL log directory
$MaxTries        = $null # Set to a number for limited attempts, or leave as $null for infinite tries
$DownloadPath    = "C:\ProgramData\TacticalRMM\temp" # This is the default recommanded folder by TRMM
$SleepBeforeExit = 20 # Timeout to leave some time to read the terminal output on the device
$TryEvery        = 30 # Duration between trials 

# Function to log messages
function Write-Log {
    param ([string]$message)

    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $logMessage = "$timestamp - $message"

    Write-Host $logMessage

    if ($logFile) {
        Add-Content -Path $logFile -Value $logMessage
    }
}

# Function to extract FQDN from Deployment URL
function Get-FQDNFromURL {
    param ([string]$url)

    if (-not [System.Uri]::IsWellFormedUriString($url, [System.UriKind]::Absolute)) {
        Write-Log "Invalid DeploymentURL: '$url'. Must be a well-formed absolute URI."
        Start-Sleep -Seconds $SleepBeforeExit
        exit 1
    }

    try {
        $uri = [Uri]$url
        $fqdn = $uri.Host

        # Simple check for valid domain or IP address
        if ($fqdn -match '^(([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}|(\d{1,3}\.){3}\d{1,3})$') {
            return "$($uri.Scheme)://$($uri.Host)"
        } else {
            Write-Log "The host part of the URL ('$fqdn') is not a valid domain or IP."
            Start-Sleep -Seconds $SleepBeforeExit
            exit 1
        }
    } catch {
        Write-Log "Failed to parse DeploymentURL '$url': $($_.Exception.Message)"
        Start-Sleep -Seconds $SleepBeforeExit
        exit 1
    }
}

# Function to check the availability of the TRMM instance
function Check-RMM-uplink {
    $baseURL = Get-FQDNFromURL -url $DeploymentURL
    try {
        Write-Log "Sending GET request to $baseURL..."
        $response = Invoke-RestMethod -Uri $baseURL -UseBasicParsing -ErrorAction Stop

        if ($null -eq $response) {
            Write-Log "ERROR Received empty response from $baseURL."
            return $false
        }

        if ($response.PSObject.Properties.Name -contains "status") {
            $statusValue = $response.status
            if ($statusValue -eq "ok") {
                Write-Log "TRMM check succeeded. Status is: $statusValue"
                return $true
            } else {
                Write-Log "ERROR TRMM responded, but status is not OK: $statusValue"
                return $false
            }
        } else {
            Write-Log "ERROR Response does not contain a 'status' field."
            return $false
        }
    } catch {
        Write-Log "ERROR Error occurred during TRMM check: $($_.Exception.Message)"
        return $false
    }
}

# Ensure the log directory exists if set
if ($logDirectory -and -not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}
$logFile        = if ($logDirectory) { Join-Path -Path $logDirectory -ChildPath "deploy_log_$(Get-Date -Format 'ddMMyyyy').log" } else { $null }

# Synchronize time
Write-Log "Synchronizing the system time..."
w32tm /resync
Restart-Service w32time

# Retry loop with optional max attempts
$attempt = 0
do {
    $rmmReady = Check-RMM-uplink
    if ($rmmReady) { break }

    $attempt++
    if ($MaxTries -ne $null -and $attempt -ge $MaxTries) {
        Write-Log "Maximum retry attempts ($MaxTries) reached. Exiting..."
        Start-Sleep -Seconds $SleepBeforeExit
        exit 1
    }

    Write-Log "Retrying in $TryEvery seconds... (Attempt #$attempt)"
    Start-Sleep -Seconds $TryEvery
} until ($rmmReady)

# Check if TRMM is already installed
$tacticalInstalled = Get-WmiObject -Query "SELECT Name FROM Win32_Service WHERE Name LIKE 'tacticalrmm'" | Select-Object -ExpandProperty Name

if (-not $tacticalInstalled) {
    Write-Log "Tactical RMM agent not found. Proceeding with installation..."
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

    # Check if Windows Defender is active before adding exclusions
    $defenderActive = Get-MpComputerStatus | Select-Object -ExpandProperty AMServiceEnabled
    if ($defenderActive) {
        Write-Log "Windows Defender is active. Adding path exclusions..."
        Add-MpPreference -ExclusionPath "C:\Program Files\TacticalAgent\*"
        Add-MpPreference -ExclusionPath "C:\Program Files\Mesh Agent\*"
        Add-MpPreference -ExclusionPath "C:\ProgramData\TacticalRMM\*"
    } else {
        Write-Log "Third-party antivirus detected. Skipping exclusion rules."
    }

    #Create download destination
    if (-not (Test-Path -Path $DownloadPath)) {
        New-Item -ItemType Directory -Path $DownloadPath | Out-Null
    }

    # Download and run the installer
    Write-Log "Downloading Tactical RMM installer..."
    Invoke-WebRequest -Uri $DeploymentURL -OutFile "$DownloadPath\tactical.exe"
    Write-Log "Launching installer..."
    Start-Process -FilePath "$DownloadPath\tactical.exe" -NoNewWindow -Wait
    Write-Log "Installation completed. Exiting..."
    Start-Sleep -Seconds $SleepBeforeExit
    exit 0

} else {
    Write-Log "Tactical RMM agent is already installed. Exiting..."
    Start-Sleep -Seconds $SleepBeforeExit
    exit 0
}

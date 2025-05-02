<#
.SYNOPSIS
    Checks for connectivity to the rmm, when found installs Tactical RMM if not already installed.

.DESCRIPTION
    This script is made to be packaged into a standard ISO and run with or after sysprep and not run from the RMM itself.
    It syncronise the system time to avoid SSL issues, checks for connectivity to 443 of the rmm server, 
    installs Tactical RMM, and logs each step of the process.
    If Windows Defender is active, it adds exclusions for Tactical RMM-related paths.
    The log are optionals


.NOTES
    Author: SAN
    Date: 01.10.2024
    #public

.EXEMPLE
    $DeploymentURL = "https://api-rmm-xxxxxxx.xxxxxxxx.xxx/clients/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/deploy/"
    $RMM_URL = "rmm-xxxxxxxxxxxxx.xxxxxx.xxxxx"
    $logDirectory = "C:\xxxxxxxx\logs"

.CHANGELOG
    SAN 02.05.25 Cleaned the code for publication and removed sensitive data

.TODO
    Querry the api with to get a "status"ok"" in json rather than a tcp check
    Run with silent argument ?

#>


$RMM_URL     = "" # Provide the rmm URL for network check
$DeploymentURL  = "" # Provide the Deployment URL
$logDirectory   = "" # Provide optional log directory


$CHECK_PORT     = 443
$tacticalPath   = "C:\ProgramData\TacticalRMM\temp"
$logFile        = Join-Path -Path $logDirectory -ChildPath "deploy_log_$(Get-Date -Format 'ddMMyyyy').log"

# Ensure the log directory exists
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

# Function to log messages
function Write-Log {
    param ([string]$message)

    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $logMessage = "$timestamp - $message"

    # If the log file is empty, use Write-Host
    if ((Test-Path -Path $logFile) -and ((Get-Item -Path $logFile).length -eq 0)) {
        Write-Host $logMessage
    } else {
        Write-Host $logMessage
        Add-Content -Path $logFile -Value $logMessage
    }
}

# Synchronize time
Write-Log "Synchronizing the system time..."
w32tm /resync
Start-Sleep -Seconds 5
Restart-Service w32time
Start-Sleep -Seconds 5

# Function to check internet connectivity
function Check-InternetConnection {
    Write-Log "Checking connectivity to $RMM_URL on port $CHECK_PORT..."
    $connectionTest = Test-NetConnection -ComputerName $RMM_URL -Port $CHECK_PORT

    if ($connectionTest.TcpTestSucceeded) {
        Write-Log "Connection to $RMM_URL successful."
        return $true
    } else {
        Write-Log "Connection failed. Retrying in 20 seconds..."
        Start-Sleep -Seconds 20
        return $false
    }
}

# Retry until connection is established
do {
    $networkAvailable = Check-InternetConnection
} until ($networkAvailable)

Start-Sleep -Seconds 5

# Check if Tactical RMM is already installed
$tacticalInstalled = Get-WmiObject -Query "SELECT Name FROM Win32_Service WHERE Name LIKE 'tacticalrmm'" | Select-Object -ExpandProperty Name

if (-not $tacticalInstalled) {
    Write-Log "Tactical RMM not found. Proceeding with installation..."

    if (-not (Test-Path -Path $tacticalPath)) {
        New-Item -ItemType Directory -Path $tacticalPath | Out-Null
    }

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

    # Download and run the installer
    if ($DeploymentURL) {
        Write-Log "Downloading Tactical RMM installer..."
        Invoke-WebRequest -Uri $DeploymentURL -OutFile "$tacticalPath\tactical.exe"
        Write-Log "Launching installer..."
        Start-Process -FilePath "$tacticalPath\tactical.exe" -NoNewWindow -Wait
        Write-Log "Installation completed."
    } else {
        Write-Log "Error: Deployment URL is not set."
    }

    Start-Sleep -Seconds 15
    exit 0
} else {
    Write-Log "Tactical RMM already installed. Exiting..."
    Start-Sleep -Seconds 15
    exit 0
}

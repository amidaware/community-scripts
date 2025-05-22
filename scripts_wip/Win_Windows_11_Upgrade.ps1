<#
.SYNOPSIS
    Upgrades Windows 10 to Windows 11 after validating system requirements.
.DESCRIPTION
    This script checks system compatibility, downloads the Windows 11 Installation Assistant,
    and initiates the upgrade process. It includes detailed error checking and reporting.
.AUTHOR
    redanthrax
.DATE
    May 6, 2025
.VERSION
    1.1 (Optimized)
.EXAMPLE
    .\Win_Windows_11_Upgrade.ps1
    This command checks system compatibility and downloads the Windows 11 Installation Assistant to install Windows 11.
.EXAMPLE
    .\Win_Windows_11_Upgrade.ps1 -Force
    This command forces the upgrade to Windows 11 and deletes drivers that are blocking the install.
.EXAMPLE
    .\Win_Windows_11_Upgrade.ps1 -Force -IsoLocation "C:\Path\To\Windows11.iso"
    This command specifies a custom ISO location for the Windows 11 installation and forces the install.
#>

# Define parameters
param(
    [switch]$Force,
    [string]$IsoLocation
)

#---------------------------------
# Configuration
#---------------------------------
$Config = @{
    Win11SetupUrl     = "https://go.microsoft.com/fwlink/?linkid=2171764"
    SetupPath         = "$env:TEMP\Win11InstallationAssistant.exe"
    IsoLocation       = $IsoLocation
    IsoPath           = "$env:TEMP\Windows11.iso"
    MountPath         = "$env:TEMP\Mount"
    LogPath           = "C:\SetupLogs"
    LogPaths          = @{
        PantherDir    = "C:\`$WINDOWS.~BT\Sources\Panther"
        SetupAct      = "C:\`$WINDOWS.~BT\Sources\Panther\setupact.log"
        SetupErr      = "C:\`$WINDOWS.~BT\Sources\Panther\setuperr.log"
        ScanResult    = "C:\`$WINDOWS.~BT\Sources\Panther\ScanResult.xml"
        CompatData    = "C:\`$WINDOWS.~BT\Sources\Panther\CompatData.xml"
        UpdateLogDir  = "$env:SystemRoot\Logs\MoSetup"
        WindowsUpdate = "$env:SystemRoot\Logs\WindowsUpdate"
        SetupDiag     = "$env:SystemRoot\Logs\SetupDiag"
    }
    TimeoutMinutes    = 180
    StatusIntervalSec = 30
    ErrorPatterns     = @('error', 'failure', 'failed', 'crash', 'compatibility', 'blockage', 'block found', 'not supported', 'rollback', 'could not complete', 'blockmigration', 'migration block', 'Result = 0x', 'HRESULT', 'Error code:')
}

# Windows Setup Error Code Dictionary
$SetupErrorCodes = @{
    # Migration errors
    "0x0000007E" = @{
        Description = "Failed to load migration components"
        Explanation = "Windows could not load the migration module (migcore.dll) required for the upgrade"
        Solution    = "Run SFC /scannow to repair system files, ensure Windows Update is fully updated, and try again"
        Category    = "Migration"
        Severity    = "High"
    }
    "0xC1900204" = @{
        Description = "Migration choice not available"
        Explanation = "System settings or configurations are not compatible with migration to Windows 11"
        Solution    = "Check system compatibility, ensure drivers are updated, and remove blocking applications"
        Category    = "Migration"
        Severity    = "High"
    }
    
    # Resource management errors
    "0xD0000003" = @{
        Description = "Resource management error (EcoQos)"
        Explanation = "Windows couldn't allocate necessary system resources to perform the upgrade"
        Solution    = "Close other applications, ensure sufficient disk space, and try restarting the system"
        Category    = "Resources"
        Severity    = "Medium"
    }
    
    # COM/Interface errors
    "0x80040154" = @{
        Description = "Interface not registered (REGDB_E_CLASSNOTREG)"
        Explanation = "A required component or interface wasn't properly registered in the system"
        Solution    = "Run the System File Checker (sfc /scannow) and DISM to repair Windows components"
        Category    = "Component"
        Severity    = "Medium"
    }
    
    # Setup process errors
    "0xC1800104" = @{
        Description = "Setup process suspension error"
        Explanation = "The upgrade process was suspended due to a critical error or compatibility issue"
        Solution    = "Check setup logs for specific compatibility issues and resolve them before retrying"
        Category    = "Setup"
        Severity    = "High"
    }
    "0x800704D3" = @{
        Description = "Process interrupted or terminated"
        Explanation = "The upgrade process was interrupted, possibly by another application or service"
        Solution    = "Close all non-essential applications and services before attempting the upgrade"
        Category    = "Setup"
        Severity    = "Medium"
    }
    
    # Hardware compatibility errors
    "0xC1900200" = @{
        Description = "System doesn't meet minimum requirements"
        Explanation = "The device doesn't meet Windows 11 hardware requirements"
        Solution    = "Check CPU, TPM, RAM, WinRE, and disk space requirements for Windows 11"
        Category    = "Hardware"
        Severity    = "Critical"
    }
    "0xC1900202" = @{
        Description = "System doesn't meet minimum requirements for update"
        Explanation = "System configuration doesn't meet Windows 11 requirements"
        Solution    = "Ensure TPM 2.0 is enabled, Secure Boot is enabled, and all hardware meets requirements"
        Category    = "Hardware"
        Severity    = "Critical"
    }
    
    # Storage errors
    "0x80070070" = @{
        Description = "Insufficient disk space"
        Explanation = "Not enough free space on the system drive for the upgrade"
        Solution    = "Free up at least 20GB of space on the system drive and try again"
        Category    = "Storage"
        Severity    = "Medium"
    }
    
    # Generic errors
    "0xC1900101" = @{
        Description = "Driver compatibility error"
        Explanation = "A driver on your system is incompatible with Windows 11"
        Solution    = "Update all device drivers to the latest versions, especially graphics, network, and storage drivers"
        Category    = "Driver"
        Severity    = "High"
    }
    "0x80004005" = @{
        Description = "Unspecified error (E_FAIL)"
        Explanation = "A general failure occurred during the upgrade process"
        Solution    = "Check for driver updates, ensure sufficient disk space, and remove third-party security software"
        Category    = "General"
        Severity    = "Medium"
    }
}

#---------------------------------
# Utility Functions
#---------------------------------

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log message to the console with timestamp and severity.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Handle-Error {
    <#
    .SYNOPSIS
        Centralized error handling function.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        $Exception
    )

    Write-Log "Error: $Message" "ERROR"
    if ($Exception) {
        $errorMessage = if ($Exception -is [System.Management.Automation.ErrorRecord]) {
            $Exception.Exception.Message
        }
        else {
            $Exception.Message
        }
        Write-Log "Details: $errorMessage" "ERROR"
    }
}

function Test-Admin {
    <#
    .SYNOPSIS
        Checks if the script is running with administrative privileges.
    #>
    $user = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $user.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Script requires administrative privileges." "ERROR"
        Start-Process PowerShell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
        exit
    }

    Write-Log "Running with administrative privileges." "INFO"
}

#---------------------------------
# Core Functions
#---------------------------------

function Test-WinREStatus {
    <#
    .SYNOPSIS
        Checks if Windows Recovery Environment (WinRE) is enabled and properly configured.
    .OUTPUTS
        Boolean indicating if WinRE is enabled and properly configured.
    #>
    try {
        $reagentInfo = reagentc /info
        $winREEnabled = $reagentInfo | Select-String "Windows RE Status:\s+Enabled"
        
        if ($winREEnabled) {
            # Verify WinRE image is registered
            $imageInfo = reagentc /info | Select-String "Windows RE location"
            if ($imageInfo -and $imageInfo.Line -notmatch "Not found") {
                Write-Log "WinRE: Enabled and properly configured" "INFO"
                return $true
            }
            else {
                Write-Log "WinRE: Enabled but image not properly registered" "WARNING"
                return $false
            }
        }
        else {
            Write-Log "WinRE: Not enabled" "ERROR"
            return $false
        }
    }
    catch {
        Handle-Error -Message "Failed to check WinRE status." -Exception $_
        return $false
    }
}

function Test-SystemCompatibility {
    <#
    .SYNOPSIS
        Validates system requirements for Windows 11, including WinRE status.
    #>
    $results = @{ TPM = $false; SecureBoot = $false; System = $false; WinRE = $false }

    # Check TPM
    try {
        $tpm = Get-Tpm
        if ($tpm.TpmPresent -and $tpm.TpmReady) {
            $tpmVersion = (Get-WmiObject -Namespace "root\CIMV2\Security\MicrosoftTpm" -Class "Win32_Tpm").SpecVersion.Split(",")[0]
            $results.TPM = $tpmVersion -ge 2
            Write-Log "TPM: $(if ($results.TPM) { 'Version 2.0 or higher detected' } else { 'Failed requirements' })" "INFO"
        }
        else {
            Write-Log "TPM not present or not ready." "ERROR"
        }
    }
    catch {
        Handle-Error -Message "Failed to check TPM." -Exception $_
    }

    # Check Secure Boot
    try {
        $results.SecureBoot = Confirm-SecureBootUEFI
        Write-Log "Secure Boot: $(if ($results.SecureBoot) { 'Enabled' } else { 'Not enabled' })" "INFO"
    }
    catch {
        Handle-Error -Message "Failed to check Secure Boot." -Exception $_
    }

    # Check system requirements
    try {
        $processor = Get-CimInstance Win32_Processor
        $memory = Get-CimInstance Win32_ComputerSystem
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $results.System = ($processor.NumberOfCores -ge 2) -and
                         ([math]::Round($memory.TotalPhysicalMemory / 1GB, 2) -ge 4) -and
                         ([math]::Round($disk.FreeSpace / 1GB, 2) -ge 64)
        Write-Log "System: $(if ($results.System) { 'Meets requirements' } else { 'Insufficient CPU, RAM, or disk space' })" "INFO"
    }
    catch {
        Handle-Error -Message "Failed to check system requirements." -Exception $_
    }

    # Check WinRE status
    try {
        $results.WinRE = Test-WinREStatus
    }
    catch {
        Handle-Error -Message "Failed to check WinRE status." -Exception $_
    }

    return $results
}

function Get-DriverBlocks {
    <#
    .SYNOPSIS
        Checks for driver migration blocks in ScanResult.xml.
    #>
    $blockedDrivers = @()
    $scanResultPath = $Config.LogPaths.ScanResult

    if (-not (Test-Path $scanResultPath)) {
        Write-Log "ScanResult.xml not found." "INFO"
        return $blockedDrivers
    }

    try {
        [xml]$scanResult = Get-Content $scanResultPath -ErrorAction Stop
        $blockedDrivers = $scanResult.CompatReport.DriverPackages.DriverPackage | Where-Object { $_.BlockMigration -eq 'True' }

        # check if $blockedDrivers is an object or an array
        if ($blockedDrivers -is [System.Xml.XmlNode]) {
            $blockedDrivers = @($blockedDrivers)
        }

        foreach ($driver in $blockedDrives) {
            $blockedDrivers += [PSCustomObject]@{
                InfFile           = $driver.Inf
                HasSignedBinaries = $driver.HasSignedBinaries
                BlockReason       = "Migration block"
            }
        }

        Write-Log "Found $($blockedDrivers.Count) driver blocks." "WARNING"
    }
    catch {
        Handle-Error -Message "Failed to parse ScanResult.xml." -Exception $_
    }

    return $blockedDrivers
}


function Check-PreviousUpgradeAttempt {
    <#
    .SYNOPSIS
        Checks for evidence of previous Windows 11 upgrade attempts.
    .PARAMETER Force
        If specified, proceeds with the upgrade but still reports critical issues.
    .OUTPUTS
        Hashtable containing details of previous attempts.
    #>
    param(
        [switch]$Force
    )

    $result = @{
        PreviousAttemptFound = $false
        FailureDetected      = $false
        FailureReason        = $null
        UpgradeDate          = $null
        LogsExist            = $false
        BlockedDrivers       = @()
        ErrorEntries         = @()
    }

    Write-Log "Checking for previous Windows 11 upgrade attempts..." "INFO"

    # Check for setup directories
    $setupDirs = @(
        $Config.LogPaths.PantherDir,
        "$env:SystemRoot\Panther",
        "$env:SystemDrive\ESD\Windows"
    )

    foreach ($dir in $setupDirs) {
        if (Test-Path $dir) {
            $result.PreviousAttemptFound = $true
            $result.LogsExist = $true
            Write-Log "Found setup directory: $dir" "INFO"

            # Get upgrade date from newest log
            $logFiles = Get-ChildItem -Path $dir -Filter "*.log" -ErrorAction SilentlyContinue
            if ($logFiles) {
                $newestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                $result.UpgradeDate = $newestLog.LastWriteTime
                Write-Log "Previous attempt detected on: $($newestLog.LastWriteTime)" "INFO"
            }
            break
        }
    }

    # Always check for driver blocks and log errors, even with -Force
    $blockedDrivers = Get-DriverBlocks
    if ($blockedDrivers.Count -gt 0) {
        $result.FailureDetected = $true
        $result.FailureReason = "Driver Compatibility Issues"
        $result.BlockedDrivers = $blockedDrivers
        Write-Log "Previous upgrade failed due to $($blockedDrivers.Count) driver blocks." "ERROR"
    }

    $errorEntries = Get-UpgradeLogErrors
    if ($errorEntries.Count -gt 0) {
        $result.ErrorEntries = $errorEntries
        if (-not $result.FailureDetected) {
            $result.FailureDetected = $true
            $result.FailureReason = "Upgrade Errors Detected"
        }

        Write-Log "Previous upgrade failed due to $($errorEntries.Count) errors in logs." "ERROR"
        Show-UpgradeFailureInfo -ErrorEntries $errorEntries
    }

    if ($result.PreviousAttemptFound -and $result.FailureDetected -and $Force) {
        Write-Log "-Force specified: Proceeding despite previous issues. Resolve reported issues to ensure success." "WARNING"
    }
    elseif ($result.PreviousAttemptFound -and -not $Force) {
        Write-Log "Previous attempt detected. Use -Force to proceed or resolve issues." "WARNING"
    }
    else {
        Write-Log "No critical issues detected from previous attempts." "INFO"
    }

    return $result
}

function Show-PreviousUpgradeAttemptInfo {
    <#
    .SYNOPSIS
        Displays information about a previous upgrade attempt.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$PreviousAttempt
    )

    if (-not $PreviousAttempt.PreviousAttemptFound) {
        return
    }

    Write-Log "Previous Windows 11 upgrade attempt detected." "WARNING"
    if ($PreviousAttempt.UpgradeDate) {
        Write-Log "Date: $($PreviousAttempt.UpgradeDate)" "INFO"
    }

    if ($PreviousAttempt.FailureDetected) {
        Write-Log "Status: Failed - $($PreviousAttempt.FailureReason)" "ERROR"
        if ($PreviousAttempt.BlockedDrivers.Count -gt 0) {
            Show-BlockedDriverInfo -BlockedDrivers $PreviousAttempt.BlockedDrivers
        }

        if ($PreviousAttempt.ErrorEntries.Count -gt 0) {
            Show-UpgradeFailureInfo -ErrorEntries $PreviousAttempt.ErrorEntries
        }

        Write-Log "Action: Address issues above. Use -Force to retry." "INFO"
    }
    else {
        Write-Log "Status: Incomplete or canceled." "WARNING"
    }
}

function Get-UpgradeLogErrors {
    <#
    .SYNOPSIS
        Parses Windows setup logs for errors and returns error entries.
    .OUTPUTS
        Array of PSCustomObjects containing error details.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Analyzing Windows setup logs for errors..." "INFO"
    $errorEntries = @()

    # Check Panther directory
    $pantherDir = $Config.LogPaths.PantherDir
    if (Test-Path $pantherDir) {
        Write-Log "Found setup logs in $pantherDir" "INFO"
        $logFiles = Get-ChildItem -Path $pantherDir -Filter "*.log" -ErrorAction SilentlyContinue

        foreach ($logFile in $logFiles) {
            Write-Log "Scanning $($logFile.Name)..." "INFO"
            $matches = Select-String -Path $logFile.FullName -Pattern $Config.ErrorPatterns -Context 2, 2 -ErrorAction SilentlyContinue
            foreach ($match in $matches) {
                $errorEntries += [PSCustomObject]@{
                    LogFile    = $logFile.Name
                    LineNumber = $match.LineNumber
                    Context    = $match.Context | Out-String
                    Line       = $match.Line
                    TimeFound  = Get-Date
                }
            }
        }
    }
    else {
        Write-Log "No setup logs found in $pantherDir" "INFO"
    }

    # Check additional log directories
    $additionalDirs = @($Config.LogPaths.UpdateLogDir, $Config.LogPaths.WindowsUpdate)
    foreach ($dir in $additionalDirs) {
        if (Test-Path $dir) {
            $logFiles = Get-ChildItem -Path $dir -Filter "*.log" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) }
            foreach ($logFile in $logFiles) {
                $matches = Select-String -Path $logFile.FullName -Pattern $Config.ErrorPatterns -Context 2, 2 -ErrorAction SilentlyContinue
                foreach ($match in $matches) {
                    $errorEntries += [PSCustomObject]@{
                        LogFile    = $logFile.Name
                        LineNumber = $match.LineNumber
                        Context    = $match.Context | Out-String
                        Line       = $match.Line
                        TimeFound  = Get-Date
                    }
                }
            }
        }
    }

    Write-Log "Found $($errorEntries.Count) error entries in logs." "INFO"
    return $errorEntries
}

function Show-BlockedDriverInfo {
    <#
    .SYNOPSIS
        Displays details about blocked drivers preventing the upgrade.
    #>
    param (
        [Parameter(Mandatory)]
        [Array]$BlockedDrivers
    )

    if ($BlockedDrivers.Count -eq 0) {
        return
    }

    Write-Log "Critical: $($BlockedDrivers.Count) incompatible drivers detected." "ERROR"
    # match the driver Inf to the driver from Parse-PnpUtilDrivers

    $pnpDrivers = Parse-PnpUtilDrivers -RunCommand
    
    foreach ($driver in $BlockedDrivers) {
        Write-Log "Driver: $($driver.Inf)" "ERROR"
        Write-Log "Matched Driver: $($pnpDrivers | Where-Object { $_."Published Name" -eq $driver.Inf } | Select-Object -ExpandProperty "Original Name")" "ERROR"
        Write-Log "Signed: $($driver.HasSignedBinaries)" "INFO"
    }

    Write-Log "Resolve these driver issues before retrying the upgrade." "WARNING"
}

function Show-UpgradeFailureInfo {
    <#
    .SYNOPSIS
        Displays detailed information about upgrade failures.
    #>
    param (
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$ErrorEntries
    )

    if ($ErrorEntries.Count -eq 0) {
        Write-Log "No errors found in logs." "INFO"
        return
    }

    Write-Log "Found $($ErrorEntries.Count) errors in upgrade logs:" "WARNING"
    foreach ($error in $ErrorEntries | Select-Object -First 3) {
        Write-Log "Log: $($error.LogFile), Line: $($error.LineNumber)" "INFO"
        Write-Log "Error: $($error.Line)" "ERROR"
        if ($error.Context) {
            Write-Log "Context:" "INFO"
            ($error.Context -split "`n" | Where-Object { $_ -match '\S' }) | ForEach-Object { Write-Log "  $_" "INFO" }
        }
    }

    if ($ErrorEntries.Count -gt 3) {
        Write-Log "... and $($ErrorEntries.Count - 3) more errors." "INFO"
    }
}

function Get-ErrorCodesFromLogs {
    <#
    .SYNOPSIS
        Extracts error codes from log entries.
    #>
    param (
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$ErrorEntries
    )

    $errorCodes = @()
    $errorCodeRegex = '0x[0-9A-F]{8}|0x[0-9A-F]{4,6}'

    foreach ($entry in $ErrorEntries) {
        if ($entry.Line -match $errorCodeRegex) {
            $matches = [regex]::Matches($entry.Line, $errorCodeRegex)
            foreach ($match in $matches) {
                if (-not $errorCodes.Contains($match.Value)) {
                    $errorCodes += $match.Value
                }
            }
        }
    }

    return $errorCodes
}

function Get-LastSetupError {
    <#
    .SYNOPSIS
        Analyzes the SetupAct.log file to find the last setup error and provides details about it.
    .DESCRIPTION
        This function parses the Windows Setup log (setupact.log) to identify the last error code,
        then uses the SetupErrorCodes dictionary to provide a description, explanation, and solution.
    .OUTPUTS
        PSCustomObject containing error details including the error code, timestamp, description, explanation, and solution.
    #>
    [CmdletBinding()]
    param()

    $setupActLogPath = $Config.LogPaths.SetupAct
    $errorCodeRegex = '0x[0-9A-F]{8}|0x[0-9A-F]{4,6}'
    $result = [PSCustomObject]@{
        ErrorFound  = $false
        ErrorCode   = $null
        Timestamp   = $null
        LogLine     = $null
        Description = $null
        Explanation = $null
        Solution    = $null
        Category    = $null
        Severity    = $null
    }

    if (-not (Test-Path $setupActLogPath)) {
        Write-Log "SetupAct.log not found at $setupActLogPath" "WARNING"
        return $result
    }

    Write-Log "Analyzing SetupAct.log for the last error..." "INFO"
    
    try {
        # Get all lines containing error codes
        $errorLines = Select-String -Path $setupActLogPath -Pattern $errorCodeRegex -ErrorAction Stop
        
        if ($errorLines.Count -eq 0) {
            Write-Log "No error codes found in SetupAct.log" "INFO"
            return $result
        }
        
        # Get the last error line
        $lastErrorLine = $errorLines | Select-Object -Last 1
        
        # Extract the error code
        $matches = [regex]::Matches($lastErrorLine.Line, $errorCodeRegex)
        if ($matches.Count -eq 0) {
            Write-Log "Error code pattern matched but no code extracted" "WARNING"
            return $result
        }
        
        $errorCode = $matches[0].Value
        
        # Try to extract timestamp from the log line
        $timestamp = if ($lastErrorLine.Line -match '^\s*\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]') {
            try {
                [datetime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)
            }
            catch {
                Get-Date
            }
        }
        else {
            Get-Date
        }
        
        # Look up error code in SetupErrorCodes dictionary
        $errorInfo = $SetupErrorCodes[$errorCode]
        if ($errorInfo) {
            $result.ErrorFound = $true
            $result.ErrorCode = $errorCode
            $result.Timestamp = $timestamp
            $result.LogLine = $lastErrorLine.Line
            $result.Description = $errorInfo.Description
            $result.Explanation = $errorInfo.Explanation
            $result.Solution = $errorInfo.Solution
            $result.Category = $errorInfo.Category
            $result.Severity = $errorInfo.Severity
            
            Write-Log "Found last error code $errorCode in SetupAct.log" "WARNING"
            Write-Log "Error: $($errorInfo.Description)" "ERROR"
            Write-Log "Explanation: $($errorInfo.Explanation)" "WARNING"
            Write-Log "Solution: $($errorInfo.Solution)" "INFO"
        }
        else {
            $result.ErrorFound = $true
            $result.ErrorCode = $errorCode
            $result.Timestamp = $timestamp
            $result.LogLine = $lastErrorLine.Line
            $result.Description = "Unknown error code"
            $result.Explanation = "This error code is not documented in the SetupErrorCodes dictionary"
            $result.Solution = "Search online for more information about this error code"
            $result.Category = "Unknown"
            $result.Severity = "Unknown"
            
            Write-Log "Found unknown error code $errorCode in SetupAct.log" "WARNING"
        }
    }
    catch {
        Handle-Error -Message "Failed to analyze SetupAct.log" -Exception $_
    }
    
    return $result
}

function Parse-PnpUtilDrivers {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string[]]$InputData,
        
        [Parameter()]
        [switch]$RunCommand
    )
    
    begin {
        $rawOutput = @()
        $drivers = @()
    }
    
    process {
        # Collect all input lines
        if ($InputData) {
            $rawOutput += $InputData
        }
    }
    
    end {
        # If the RunCommand switch is specified, execute pnputil and get its output
        if ($RunCommand) {
            $rawOutput = pnputil /enum-drivers
        }
        
        # If we have no input, exit
        if (-not $rawOutput) {
            Write-Warning "No input data provided."
            return
        }
        
        # Join all lines into a single string
        $outputText = $rawOutput -join "`n"
        
        # Split the output into blocks for each driver
        # Each driver entry is separated by one or more blank lines
        $driverBlocks = $outputText -split '(?m)^\s*$\s*(?=Published Name:|$)' | Where-Object { $_ -match '\S' }
        
        foreach ($block in $driverBlocks) {
            # Create a hashtable to store driver properties
            $driverProps = [ordered]@{}
            
            # Get each line in the block
            $lines = $block -split "`n"
            $currentKey = $null
            $currentValue = $null
            
            foreach ($line in $lines) {
                # Check if this is a key-value line
                if ($line -match '^\s*([^:]+):\s*(.*)$') {
                    # If we have a stored key and value, add them to the properties
                    if ($currentKey) {
                        $driverProps[$currentKey] = $currentValue.Trim()
                    }
                    
                    # Store the new key and value
                    $currentKey = $matches[1].Trim()
                    $currentValue = $matches[2]
                }
                # If this is a continuation of a value (indented line)
                elseif ($line -match '^\s+(.+)$' -and $currentKey) {
                    $currentValue += " " + $matches[1]
                }
            }
            
            # Add the last key-value pair
            if ($currentKey) {
                $driverProps[$currentKey] = $currentValue.Trim()
            }
            
            # Create a custom object from the properties
            $driverObj = [PSCustomObject]$driverProps
            $drivers += $driverObj
        }
        
        return $drivers
    }
}

function Start-IsoUpgrade {
    try {
        # Check for existing driver blocks
        Write-Log "Checking for driver compatibility issues before starting ISO upgrade..." "INFO"
        $blockedDrivers = Get-DriverBlocks
        if ($blockedDrivers.Count -gt 0) {
            Write-Log "Critical: $($blockedDrivers.Count) driver blocks detected." "ERROR"
            if (-not $Force) {
                Write-Log "Upgrade cannot proceed due to driver blocks. Use -Force to override after resolving issues." "ERROR"
                return $false
            }
            else {
                Write-Log "-Force specified: Proceeding despite driver blocks. Ensure drivers are resolved." "WARNING"
            }
        }

        # Ensure directories exist
        $dirs = @($Config.IsoPath, $Config.MountPath, $Config.LogPath)
        foreach ($dir in $dirs) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }

        # Download the ISO
        Write-Log "Downloading Windows 11 ISO from $IsoLocation..." "INFO"
        $retryCount = 3
        $success = $false
        for ($i = 1; $i -le $retryCount; $i++) {
            try {
                (New-Object System.Net.WebClient).DownloadFile($IsoLocation, $Config.IsoPath)
                $success = $true
                break
            }
            catch {
                Write-Log "Download attempt $i failed: $($_.Exception.Message)" "WARNING"
                if ($i -eq $retryCount) {
                    Write-Log "Failed to download ISO after $retryCount attempts." "ERROR"
                    return $false
                }

                Start-Sleep -Seconds 5
            }
        }

        if (-not $success -or -not (Test-Path $Config.IsoPath)) {
            Write-Log "Failed to download ISO." "ERROR"
            return $false
        }

        Write-Log "Download completed: $($Config.IsoPath)" "INFO"
        # Mount the ISO
        Write-Log "Mounting ISO at $($Config.MountPath)..." "INFO"
        if (-not (Test-Path $Config.MountPath)) {
            New-Item -Path $Config.MountPath -ItemType Directory -Force | Out-Null
        }

        Mount-DiskImage -ImagePath $Config.IsoPath -ErrorAction Stop
        $driveLetter = (Get-DiskImage -ImagePath $Config.IsoPath | Get-Volume).DriveLetter
        if (-not $driveLetter) {
            Write-Log "Failed to mount ISO. No drive letter assigned." "ERROR"
            return $false
        }

        Write-Log "ISO mounted at drive $driveLetter" "INFO"
        $systemDrive = $env:SystemDrive
        Write-Log "Checking BitLocker status for $systemDrive..." "INFO"
        try {
            $bitLockerVolume = Get-BitLockerVolume -MountPoint $systemDrive -ErrorAction Stop
            $protectionStatus = $bitLockerVolume.ProtectionStatus
            Write-Log "BitLocker Protection Status: $protectionStatus" "INFO"
        }
        catch {
            Write-Log "Error checking BitLocker status: $_" "ERROR"
        }

        if ($protectionStatus -eq 'On') {
            try {
                Write-Log "Suspending BitLocker protection for $systemDrive..." "WARNING"
                Suspend-BitLocker -MountPoint $systemDrive -ErrorAction Stop
                # Verify suspension
                $newStatus = (Get-BitLockerVolume -MountPoint $systemDrive).ProtectionStatus
                if ($newStatus -eq 'Off') {
                    Write-Log "BitLocker protection successfully suspended for $systemDrive." "WARNING"
                }
                else {
                    Write-Log "Failed to confirm BitLocker suspension. Please check manually with 'Get-BitLockerVolume -MountPoint $systemDrive'." "WARNING"
                }
            }
            catch {
                Write-Log "Error suspending BitLocker: $_" "ERROR"
                return $false
            }
        }


        $isoRoot = "${driveLetter}:\"
        # Run setup.exe 
        $setupExe = Join-Path $isoRoot "setup.exe"
        $setupArgs = "/auto upgrade /compat ignorewarning /eula accept /dynamicupdate disable /bitlocker alwayssuspend /migratedrivers none /copylogs $($Config.LogPath)"
        Write-Log "Starting Windows 11 ISO upgrade..." "INFO"
        $process = Start-Process -FilePath $setupExe -ArgumentList $setupArgs -PassThru -ErrorAction Stop
        $process.WaitForExit()
        Write-Log "Upgrade process completed with exit code: $($process.ExitCode)" "INFO"

        # Dismount ISO
        Write-Log "Dismounting ISO..." "INFO"
        Dismount-DiskImage -ImagePath $Config.IsoPath -ErrorAction SilentlyContinue

        return $process.ExitCode -eq 0
    }
    catch {
        Handle-Error -Message "Failed to initiate ISO upgrade." -Exception $_
        if (Get-DiskImage -ImagePath $Config.IsoPath -ErrorAction SilentlyContinue) {
            Dismount-DiskImage -ImagePath $Config.IsoPath -ErrorAction SilentlyContinue
        }
        return $false
    }
}

function Start-Upgrade {
    try {
        # Check for existing driver blocks
        Write-Log "Checking for driver compatibility issues before starting upgrade..." "INFO"
        $blockedDrivers = Get-DriverBlocks
        if ($blockedDrivers.Count -gt 0) {
            Write-Log "Critical: $($blockedDrivers.Count) driver blocks detected." "ERROR"
            if (-not $Force) {
                Write-Log "Upgrade cannot proceed due to driver blocks. Use -Force to override after resolving issues." "ERROR"
                return $false
            }
            else {
                Write-Log "-Force specified: Proceeding despite driver blocks. Ensure drivers are resolved." "WARNING"
            }
        }

        Write-Log "Downloading Windows 11 Installation Assistant..." "INFO"
        $retryCount = 3
        $success = $false
        for ($i = 1; $i -le $retryCount; $i++) {
            try {
                (New-Object System.Net.WebClient).DownloadFile($Config.Win11SetupUrl, $Config.SetupPath)
                $success = $true
                break
            }
            catch {
                Write-Log "Download attempt $i failed: $($_.Exception.Message)" "WARNING"
                if ($i -eq $retryCount) { throw "Failed to download after $retryCount attempts." }
                Start-Sleep -Seconds 5
            }
        }

        if (-not $success -or -not (Test-Path $Config.SetupPath)) {
            throw "Failed to download Installation Assistant."
        }

        Write-Log "Starting Windows 11 upgrade process..." "INFO"
        $dir = "$($env:SystemDrive)\_Windows_FU\packages"
        $process = Start-Process -FilePath $Config.SetupPath -ArgumentList "/quietinstall /skipeula /skipcompatcheck /skipselfupdate /auto upgrade /copylogs $dir" -PassThru -ErrorAction Stop
        $process.WaitForExit()
        Write-Log "Upgrade process completed with exit code: $($process.ExitCode)" "INFO"
        return $process.ExitCode -eq 0
    }
    catch {
        Handle-Error -Message "Failed to initiate upgrade." -Exception $_
        return $false
    }
}

#---------------------------------
# Main Execution
#---------------------------------

Write-Log "Starting Windows 11 Script..." "INFO"
Test-Admin

# Check for previous upgrade attempts
$previousAttempt = Check-PreviousUpgradeAttempt -Force:$Force
if ($previousAttempt.PreviousAttemptFound -and -not $Force) {
    Show-PreviousUpgradeAttemptInfo -PreviousAttempt $previousAttempt
    if ($previousAttempt.FailureDetected) {
        Get-LastSetupError
        Write-Log "Previous upgrade failure detected. Use -Force to retry." "ERROR"
        Write-Log "Attempting to download SetupDiag for further analysis..." "INFO"
        $setupDiagUrl = "https://go.microsoft.com/fwlink/?linkid=870142"
        $setupDiagPath = "$PSScriptRoot\SetupDiag.exe"
        Invoke-WebRequest -Uri $setupDiagUrl -OutFile $setupDiagPath
        Write-Log "SetupDiag downloaded to $setupDiagPath, executing SetupDiag" "INFO"
        Start-Process -FilePath $setupDiagPath -ArgumentList "/Output:$PSScriptRoot\SetupDiagResults.log" -Wait
        Get-Content "$PSScriptRoot\SetupDiagResults.log"
        exit 1
    }
}
elseif ($previousAttempt.PreviousAttemptFound -and $Force) {
    Show-PreviousUpgradeAttemptInfo -PreviousAttempt $previousAttempt
    if ($previousAttempt.FailureDetected) {
        Write-Log "Force specified: Attempting auto remediation" "WARNING"
        if ($previousAttempt.BlockedDrivers.Count -gt 0) {
            $previousAttempt.BlockedDrivers | ForEach-Object {
                Write-Log "Attempting to remove driver: $($_.Inf)" "INFO"
                pnputil /delete-driver $_.Inf /force
            }
        }
    }
}

# Validate system compatibility
$compat = Test-SystemCompatibility
if (-not ($compat.TPM -and $compat.SecureBoot -and $compat.System -and $compat.WinRE)) {
    Write-Log "System does not meet Windows 11 requirements." "ERROR"
    exit 1
}

# Start upgrade
$upgradeSuccess = if ($IsoLocation) {
    Write-Log "IsoLocation specified ($IsoLocation). Using ISO-based upgrade." "INFO"
    Start-IsoUpgrade
}
else {
    Write-Log "No IsoLocation specified. Using Windows 11 Installation Assistant." "INFO"
    Start-Upgrade
}

if (-not $upgradeSuccess) {
    Write-Log "Upgrade failed. Check logs for details." "ERROR"
    exit 1
}

Write-Log "Upgrade started successfully." "INFO"
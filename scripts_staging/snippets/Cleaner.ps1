<# 
.SYNOPSIS
    Automate cleaning up the C:\ drive with low disk space warning.

.DESCRIPTION
    Cleans the C: drive's Windows Temporary files, Windows SoftwareDistribution folder, 
    the local users Temporary folder, IIS logs(if applicable) and empties the recycle bin. 
    By default this script leaves files that are newer than 30 days old however this variable can be edited.
    This script will typically clean up anywhere from 1GB up to 15GB of space from a C: drive.


.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.EXEMPLE
    DaysToDelete=25

.CHANGELOG
    25.10.24 SAN Changed to 25 day of IIS logs
    19.11.24 SAN Added adobe updates folder to cleanup
    19.11.24 SAN removed colors
    19.11.24 SAN added cleanup of search index
    17.12.24 SAN Full code refactoring, set a single value for file expiration
    14.01.25 SAN More verbose output for the deletion of items
    11.08.25 SAN Run cleanmgr in the background
    
.TODO
    Integrate bleachbit this would help avoid having to update this script too often.
    add days to array to overide defaut day to delete in some folder
#>

# Check environment variable and set default if not defined
$DaysToDelete = if ([string]::IsNullOrEmpty($env:DaysToDelete)) { 30 } else { [int]$env:DaysToDelete }

Write-Host "Days to delete set to: $DaysToDelete"

$VerbosePreference = "Continue"
$ErrorActionPreference = "SilentlyContinue"
$Starters = Get-Date  

# Function to retrieve and display disk space info
function Get-DiskInfo {
    $DiskInfo = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveTypCleaner
                    Write-Host "[DONE] Cleaned up directory: $Path"
                } else {
                    Write-Host "[INFO] No items met the age condition in directory: $Path"
                }
            } catch {
                Write-Host "[ERROR] Failed to clean up directory: $Path. $_"
            }
        }
    } else {
        Write-Host "[WARNING] $Path does not exist, skipping cleanup."
    }
}


# Function to add or update registry keys for Disk Cleanup
function Add-RegistryKeys-CleanMGR {
    $baseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    $valueName = "StateFlags0001"
    $value = 2

    # Get all subkeys except the one named "StateFlags0001"
    $subKeys = Get-ChildItem -Path $baseKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -ne $valueName }

    foreach ($subKey in $subKeys) {
        $keyPath = $subKey.PSPath

        # Add or update the StateFlags0001 property
        New-ItemProperty -Path $keyPath -Name $valueName -Value $value -PropertyType DWORD -Force | Out-Null
    }
    Write-Host "StateFlags0001 DWORD value successfully created/updated for all subkeys under $baseKey."
}

# Cleanup paths grouped by purpose
$PathsToClean = @{
    "SystemTemp"           = "$env:windir\Temp\*"
    "Minidump"             = "$env:windir\minidump\*"
    "Prefetch"             = "$env:windir\Prefetch\*"
    "MemoryDump"           = "$env:windir\memory.dmp"
    "RecycleBin"           = "C:\$Recycle.Bin"
    "AdobeARM"             = "C:\ProgramData\Adobe\ARM"
    "SoftwareDistribution" = "C:\Windows\SoftwareDistribution"
    "CSBack"               = "C:\csback"
    "CBSLogs"              = "C:\Windows\logs\CBS\*.log"
    "IISLogs"              = "C:\inetpub\logs\LogFiles"
    "ConfigMsi"            = "C:\Config.Msi"
    "Intel"                = "C:\Intel"
    "PerfLogs"             = "C:\PerfLogs"
    "ErrorReporting"       = "C:\ProgramData\Microsoft\Windows\WER"
    "PreviousWindows"      = "C:\Windows.old"
}

# User-specific cleanup paths
$UserPathsToClean = @{
    "UserTemp"                = "C:\Users\*\AppData\Local\Temp\*"
    "ErrorReporting"          = "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*"
    "TempInternetFiles"       = "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*"
    "IECache"                 = "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\*"
    "IECompatUaCache"         = "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\*"
    "IEDownloadHistory"       = "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\*"
    "INetCache"               = "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*"
    "INetCookies"             = "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\*"
    "TerminalServerCache"     = "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\*"
}

# Display disk space before cleanup
Write-Host "[INFO] Retrieving current disk percent free for comparison after script completion."
$Before = Get-DiskInfo | Format-Table -AutoSize | Out-String

# Stop Windows Update service
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue -Verbose

# Adjust SCCM cache size if configured
$cache = Get-WmiObject -Namespace root\ccm\SoftMgmtAgent -Class CacheConfig
if ($cache) {
    $cache.size = 1024
    $cache.Put() | Out-Null
    Restart-Service ccmexec -ErrorAction SilentlyContinue
}

# Compaction of Windows.edb
$windowsEdbPath = "$env:ALLUSERSPROFILE\\Microsoft\\Search\\Data\\Applications\\Windows\\Windows.edb"
if (Test-Path $windowsEdbPath) {
    Write-Host "Disabling Windows Search service..."
    Set-Service -Name wsearch -StartupType Disabled
    Stop-Service -Name wsearch -Force
    Write-Host "Performing offline compaction of the Windows.edb file..."
    Start-Process -FilePath "esentutl.exe" -ArgumentList "/d `"$windowsEdbPath`"" -NoNewWindow -Wait
    Write-Host "Compaction completed."
    Set-Service -Name wsearch -StartupType Automatic
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\wsearch" -Name DelayedAutostart -Value 1
    Start-Service -Name wsearch
    Write-Host "Windows Search service restarted."
} else {
    Write-Host "[WARNING] Windows.edb file not found, skipping compaction."
}

# Empty recycle bin based on PowerShell version
if ($PSVersionTable.PSVersion.Major -le 4) {
    $Recycler = (New-Object -ComObject Shell.Application).NameSpace(0xA)
    $Recycler.Items() | ForEach-Object {
        Remove-Item -Path $_.Path -Force -Recurse -Verbose
    }
    Write-Host "[DONE] The recycle bin has been cleaned successfully!"
} elseif ($PSVersionTable.PSVersion.Major -ge 5) {
    Clear-RecycleBin -DriveLetter C: -Force -Verbose
    Write-Host "[DONE] The recycle bin has been cleaned successfully!"
}

# Perform cleanup for system paths
foreach ($Path in $PathsToClean.Values) {
    Remove-Items -Path $Path -Days $DaysToDelete
}

# Perform cleanup for user paths
foreach ($Path in $UserPathsToClean.Values) {
    Remove-Items -Path $Path -Days $DaysToDelete
}

# Add registry keys for Disk Cleanup
Add-RegistryKeys-CleanMGR

# Run Disk Cleanup with custom settings
$processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$processStartInfo.FileName = "cleanmgr.exe"
$processStartInfo.Arguments = "/sagerun:1"
$processStartInfo.UseShellExecute = $true  # Allows the executable to run independently
$processStartInfo.CreateNoWindow = $true   # Prevents a new window from being created
# Start the process (no wait)
[System.Diagnostics.Process]::Start($processStartInfo) | Out-Null

# Gather disk usage after cleanup
$After = Get-DiskInfo | Format-Table -AutoSize | Out-String

# Restart Windows Update service
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

# Calculate and display elapsed time
$Enders = Get-Date
$ElapsedTime = ($Enders - $Starters).TotalSeconds
Write-Host "[DONE] Script finished"
Write-Host "[INFO] Elapsed Time: $ElapsedTime seconds"
Write-Host "[INFO] Before Cleanup: $Before"
Write-Host "[INFO] After Cleanup: $After"

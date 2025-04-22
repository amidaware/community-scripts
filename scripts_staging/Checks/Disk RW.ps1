<#
.SYNOPSIS
    Tests disk read and write speeds using a specified test file, with thresholds configurable via environment variables.

.DESCRIPTION
    The Test-DiskSpeed function creates a 1GB test file (or size specified by the user) at the location specified by the 
    environment variable 'target_file', measures the write and read speeds, and returns the results. The script then 
    checks these speeds against predefined thresholds which can be overridden by environment variables

.EXEMPLE
    READ_WARN_THRESHOLD_MBPS=2000
    READ_ERROR_THRESHOLD_MBPS=1500
    WRITE_WARN_THRESHOLD_MBPS=80
    WRITE_ERROR_THRESHOLD_MBPS=50
    TARGET_FILE=C:\TestdiskRWspeed.tmp

.OUTPUTS
    Outputs the write and read speeds in MB/s.
    Exits with:
    - 0: All speeds are above the defined thresholds.
    - 1: At least one speed is below the warning threshold or if the target file environment variable is empty.
    - 2: At least one speed is below the error threshold.

.NOTES
    Author: SAN
    Date: 07.10.24
    #public

.CHANGELOG
    SAN 11.12.24 Moved vars to env
    SAN 17.04.25 Default to temp dir if no value provided and code cleanup
#>

# Set thresholds from environment or fallback to defaults
$ReadWarnThresholdMBps  = [int]($env:READ_WARN_THRESHOLD_MBPS  || 2000)
$ReadErrorThresholdMBps = [int]($env:READ_ERROR_THRESHOLD_MBPS || 1500)
$WriteWarnThresholdMBps = [int]($env:WRITE_WARN_THRESHOLD_MBPS || 80)
$WriteErrorThresholdMBps = [int]($env:WRITE_ERROR_THRESHOLD_MBPS || 50)

# Function to test disk speed
function Test-DiskSpeed {
    param (
        [string]$TestFile = $(if ($env:target_file) { $env:target_file } else { "C:\Windows\Temp\disk_test.tmp" }),
        [int]$FileSizeInMB = 1024
    )

    $buffer = New-Object byte[] (1MB)
    $rnd = New-Object Random

    # Write test
    $writeStart = Get-Date
    $stream = [System.IO.File]::Create($TestFile)
    for ($i = 0; $i -lt $FileSizeInMB; $i++) {
        $rnd.NextBytes($buffer)
        $stream.Write($buffer, 0, $buffer.Length)
    }
    $stream.Close()
    $writeDuration = (Get-Date) - $writeStart
    $writeSpeedMBps = $FileSizeInMB / $writeDuration.TotalSeconds

    # Read test
    $readStart = Get-Date
    $stream = [System.IO.File]::OpenRead($TestFile)
    while ($stream.Read($buffer, 0, $buffer.Length)) { }
    $stream.Close()
    $readDuration = (Get-Date) - $readStart
    $readSpeedMBps = $FileSizeInMB / $readDuration.TotalSeconds

    Remove-Item -Force $TestFile

    return [pscustomobject]@{
        WriteSpeedMBps = [math]::Round($writeSpeedMBps, 2)
        ReadSpeedMBps  = [math]::Round($readSpeedMBps, 2)
        TestFile       = $TestFile
    }
}

# Run and evaluate
$speedResults = Test-DiskSpeed

Write-Output "W: $($speedResults.WriteSpeedMBps) MB/s"
Write-Output "R: $($speedResults.ReadSpeedMBps) MB/s"
Write-Output "T: $($speedResults.TestFile)"

if (
    $speedResults.WriteSpeedMBps -lt $WriteErrorThresholdMBps -or 
    $speedResults.ReadSpeedMBps -lt $ReadErrorThresholdMBps
) {
    exit 2
} elseif (
    $speedResults.WriteSpeedMBps -lt $WriteWarnThresholdMBps -or 
    $speedResults.ReadSpeedMBps -lt $ReadWarnThresholdMBps
) {
    exit 1
} else {
    exit 0
}

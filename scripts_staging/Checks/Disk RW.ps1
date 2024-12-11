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
#>

# Variables for thresholds with default values from environment or script
$ReadWarnThresholdMBps = [int]$env:READ_WARN_THRESHOLD_MBPS
$ReadErrorThresholdMBps = [int]$env:READ_ERROR_THRESHOLD_MBPS
$WriteWarnThresholdMBps = [int]$env:WRITE_WARN_THRESHOLD_MBPS
$WriteErrorThresholdMBps = [int]$env:WRITE_ERROR_THRESHOLD_MBPS

# Set default values if environment variables are not set
if (-not $ReadWarnThresholdMBps) { $ReadWarnThresholdMBps = 2000 }
if (-not $ReadErrorThresholdMBps) { $ReadErrorThresholdMBps = 1500 }
if (-not $WriteWarnThresholdMBps) { $WriteWarnThresholdMBps = 80 }
if (-not $WriteErrorThresholdMBps) { $WriteErrorThresholdMBps = 50 }

# Function to test disk speed using a test file
function Test-DiskSpeed {
    param (
        [string]$TestFile = $env:target_file,  # Get target file from environment variable
        [int]$FileSizeInMB = 1024
    )

    # Check if the environment variable is set
    if (-not $TestFile) {
        Write-Output "Error: Environment variable 'target_file' is not set or is empty."
        exit 1  # Exit with warning code if the variable is not set or empty
    }
    
    # Create a buffer for writing
    $buffer = New-Object byte[] (1MB)
    $rnd = New-Object Random

    # Write speed test
    $writeStart = Get-Date
    $stream = [System.IO.File]::Create($TestFile)
    for ($i = 0; $i -lt $FileSizeInMB; $i++) {
        $rnd.NextBytes($buffer)
        $stream.Write($buffer, 0, $buffer.Length)
    }
    $stream.Close()
    $writeEnd = Get-Date
    $writeDuration = ($writeEnd - $writeStart).TotalSeconds
    $writeSpeedMBps = $FileSizeInMB / $writeDuration

    # Read speed test
    $readStart = Get-Date
    $stream = [System.IO.File]::OpenRead($TestFile)
    while ($stream.Read($buffer, 0, $buffer.Length)) {
        # Reading the file
    }
    $stream.Close()
    $readEnd = Get-Date
    $readDuration = ($readEnd - $readStart).TotalSeconds
    $readSpeedMBps = $FileSizeInMB / $readDuration

    # Cleanup
    Remove-Item $TestFile

    return [pscustomobject]@{
        WriteSpeedMBps = [math]::Round($writeSpeedMBps, 2)
        ReadSpeedMBps = [math]::Round($readSpeedMBps, 2)
    }
}

# Run the test
$speedResults = Test-DiskSpeed

# Output the results
Write-Output "W: $($speedResults.WriteSpeedMBps) MB/s"
Write-Output "R: $($speedResults.ReadSpeedMBps) MB/s"
Write-Output "T: $env:target_file "

# Check conditions for exit codes based on thresholds
if ($speedResults.WriteSpeedMBps -lt $WriteErrorThresholdMBps -or $speedResults.ReadSpeedMBps -lt $ReadErrorThresholdMBps) {
    exit 2  # Error condition if below error thresholds
} elseif ($speedResults.WriteSpeedMBps -lt $WriteWarnThresholdMBps -or $speedResults.ReadSpeedMBps -lt $ReadWarnThresholdMBps) {
    exit 1  # Warning condition if below warning thresholds
} else {
    exit 0  # All good
}

<#
.SYNOPSIS
    This script expands the partitions on a disk to use the maximum available space.
    It can expand all partitions with assigned drive letters or target a specific partition
    based on the drive letter provided via the `-ForceLetter` parameter.

.DESCRIPTION
    The script scans all partitions on the system that have a drive letter assigned. For each partition,
    it checks if there is available space that can be used to expand the partition to its maximum possible size.
    If the `-ForceLetter` parameter is provided, the script will only attempt to expand the partition
    corresponding to that drive letter.

    Before expanding any partition, the script checks if the disk contains a recovery partition.
    If a recovery partition is found, the script skips expanding any partitions on that disk to prevent
    potential issues with system recovery.

.PARAMETER ForceLetter
    Optional. Specifies the drive letter of the partition to expand. If this parameter is provided,
    only the specified partition will be processed. If the drive letter is invalid or does not exist,
    an error message will be displayed.

.NOTE
    Author: SAN
    Date: 19.08.24
    #public


#>


param (
    [string]$ForceLetter
)

# Function to check for the presence of a recovery partition on a disk
function Check-RecoveryPartition {
    param (
        [int]$DiskNumber
    )

    # Create a diskpart script to list partitions on the specified disk
    $diskpartScriptContent = "select disk $DiskNumber `n list partition"

    # Write the diskpart script to a temporary file
    $tempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempFile, $diskpartScriptContent)

    # Run the diskpart script and capture the output
    $diskpartOutput = & diskpart /s $tempFile

    # Convert the output to an array of lines
    $lines = $diskpartOutput -split "`n"

    # Check if the output contains a recovery partition
    $recoveryLine = $lines | Where-Object { $_ -match "Recovery" }

    # Cleanup temporary file
    Remove-Item $tempFile -ErrorAction SilentlyContinue

    return $recoveryLine -match "Recovery"
}

# Function to expand a partition to its maximum available size
function Expand-Partition {
    param (
        [string]$DriveLetter,
        [int]$DiskNumber,
        [int]$PartitionNumber
    )

    # Check if the disk contains a recovery partition
    if (Check-RecoveryPartition -DiskNumber $DiskNumber) {
        Write-Output "Recovery partition found on Disk $DiskNumber. Skipping expansion for partition $DriveLetter."
        Write-Output "----"
        return
    }

    # Get the partition with the specified drive letter
    $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $DriveLetter -and $_.DiskNumber -eq $DiskNumber -and $_.PartitionNumber -eq $PartitionNumber }

    if ($partition) {
        # Get the current size of the partition
        $currentSize = $partition.Size
        
        # Get the maximum size available for the partition
        $size = Get-PartitionSupportedSize -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber

        # Calculate the new size and difference
        $newSize = $size.SizeMax
        $sizeDifference = $newSize - $currentSize

        Write-Output "Partition $($partition.DriveLetter):"
        Write-Output "  Disk Number: $DiskNumber"
        Write-Output "  Partition Number: $PartitionNumber"
        Write-Output "  Current Size: $([math]::round($currentSize / 1GB, 2)) GB"
        Write-Output "  Maximum Size: $([math]::round($newSize / 1GB, 2)) GB"
        Write-Output "  Size Difference: $([math]::round($sizeDifference / 1GB, 2)) GB"
        
        if ($currentSize -lt $newSize) {
            try {
                Write-Output "  Expanding partition..."
                Resize-Partition -DriveLetter $DriveLetter -Size $newSize
                Write-Output "  Expansion successful."
            } catch {
                Write-Output "  Error expanding partition: $_"
            }
        } else {
            Write-Output "  Partition is already at its maximum size."
        }
        
        Write-Output "----"
    } else {
        Write-Output "  Partition with drive letter $DriveLetter not found."
    }
}

# Function to expand all partitions with drive letters
function Expand-AllPartitions {
    # Get all drives and their partitions
    $partitions = Get-Partition

    foreach ($partition in $partitions) {
        # Retrieve drive letter
        $driveLetter = $partition.DriveLetter

        # Skip partitions without a drive letter
        if (-not $driveLetter) {
            continue
        }

        # Retrieve disk number and partition number
        $diskNumber = $partition.DiskNumber
        $partitionNumber = $partition.PartitionNumber

        # Call Expand-Partition for each drive letter
        Expand-Partition -DriveLetter $driveLetter -DiskNumber $diskNumber -PartitionNumber $partitionNumber
    }
}

# Determine which partitions to expand
if ($ForceLetter) {
    # Get the partition with the specified drive letter
    $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $ForceLetter }

    if ($partition) {
        # Call Expand-Partition for the specified drive letter
        Expand-Partition -DriveLetter $ForceLetter -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber
    } else {
        Write-Output "Drive letter $ForceLetter not found."
    }
} else {
    # Expand all partitions with drive letters
    Expand-AllPartitions
}
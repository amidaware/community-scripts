<#
.SYNOPSIS
    This script optimizes VHDX files by performing cleanup, defragmentation, and compaction, with options for targeted or random selection and download folder management.

.DESCRIPTION
    This PowerShell script optimizes VHDX files located in a specified directory. 
    It performs the following tasks:
    - Cleanup operations to remove temporary files and optionally clean the Downloads folder.
    - Defragments the disks to improve performance.
    - Compacts the VHDX files to reduce their size.
    
    The script behavior can be controlled using environment variables:
    - Specify the directory containing VHDX files.
    - Optionally target a specific VHDX file or randomly process 50% of the files.
    - Enable or disable cleanup of the Downloads folder.

.EXEMPLE
    VHDX_PATH
        Specifies the path where the VHDX files are located.
    RANDOM_PICKS
        If set to "1", the script will randomly pick 50% of the VHDX files for optimization. Default is to process all files.
    VHDX_TARGET
        Specifies the name of a specific VHDX file to be optimized. If specified, only the targeted VHDX file will be optimized.
    ENABLE_DOWNLOAD_CLEANUP
        If set to "1", the script cleans up the Downloads folder in the mounted VHDX images. Default is to skip this step.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG
    29/08/24 SAN Swapped Write-Host to Write-Output
    19/09/24 SAN Added a disabled flag to avoid alerts
    23/10/24 SAN Prepared download cleanup 
    28/11/24 SAN Updated script to use environment variables to prep transfers to snippet and added download cleanup toggle
    28/11/24 SAN added Temporary Internet Files

.TODO
    - Investigate "compact vdisk" errors related to non-read-only mode
    - Finalize download cleanup implementation. 
    - Logoff only 1 user when using target

#>

# Read environment variables
$Path = $env:VHDX_PATH
$RandomPicks = $env:RANDOM_PICKS -eq "1"
$Target = $env:VHDX_TARGET
$EnableDownloadCleanup = $env:ENABLE_DOWNLOAD_CLEANUP -eq "1"

# Check if Get-RDUserSession is available, if not exit with code 0
try {
    $null = Get-RDUserSession -ErrorAction Stop
}
catch {
    if ($_.Exception.Message -match "A Remote Desktop Services deployment does not exist") {
        Write-Output "Remote Desktop Services deployment does not exist. Exiting."
        exit 0
    }
    else {
        Write-Output "An unexpected error occurred while checking for RDS deployment."
        Write-Output "Error: $($_.Exception.Message)"
        exit 0
    }
}

# Check if the path contains the word "disabled"
if ($Path -like "*disabled*") {
    Write-Output "Script disabled for this server"
    exit 0
}

# Check if the specified path exists
if (-not (Test-Path $Path)) {
    Write-Output "Specified path '$Path' does not exist or is invalid."
    exit 1
}

# Close active user sessions
Write-Output "Closing active user sessions..."
Get-RDUserSession | ForEach-Object {
    Write-Output "Logging off session ID $($_.UnifiedSessionId) on host $($_.HostServer)..."
    Invoke-RDUserLogoff -HostServer $_.HostServer -UnifiedSessionID $_.UnifiedSessionId -Force
}

# Define function to perform cleanup, defragmentation, and compaction
function Optimize-VHDX {
    param (
        [string]$VHDXFilePath
    )

    Write-Output "Processing VHDX file: $VHDXFilePath"
    
    # Mount VHDX
    Write-Output "Mounting VHDX file: $VHDXFilePath..."
    Mount-DiskImage $VHDXFilePath -ErrorAction Stop
    $mountedDisk = Get-DiskImage $VHDXFilePath | Get-Disk | Get-Partition
    if (-not $mountedDisk) {
        Write-Output "Failed to mount disk: $VHDXFilePath"
        return
    }
    $driveLetter = $mountedDisk.DriveLetter

    # Cleanup temporary files
    Write-Output "Cleaning up temporary files on drive $driveLetter..."
    $tempPaths = @(
        "$driveLetter\Windows\Temp",
        "$driveLetter\Users\*\AppData\Local\Temp",
        "$driveLetter\Users\*\AppData\Local\Microsoft\Windows\INetCache",
        "$driveLetter\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files"

    )
    foreach ($tempPath in $tempPaths) {
        if (Test-Path $tempPath) {
            Write-Output "Removing temporary files from $tempPath..."
            Get-ChildItem $tempPath -Include * -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    # Conditional cleanup of Downloads folder
    if ($EnableDownloadCleanup) {
        Write-Output "Cleaning up Downloads folder..."
        $downloadPaths = "$driveLetter\Users\*\Downloads"
        $timeLimit = (Get-Date).AddDays(-30)
        $noticeFileName = "Downloads Notice - Files in this folder will be deleted regularly.txt"

        # Content of the notice in multiple languages
        $noticeFileContent = @"
Les fichiers dans ce dossier seront supprimés régulièrement s'ils sont âgés de plus de 30 jours.
The files in this folder will be deleted regularly if they are older than 30 days.
"@

        # Create or overwrite the notice file in each Downloads folder
        foreach ($path in (Get-ChildItem -Path $downloadPaths -Directory -Recurse)) {
            $noticeFilePath = Join-Path -Path $path.FullName -ChildPath $noticeFileName
            if (Test-Path -Path $noticeFilePath) {
                Remove-Item -Path $noticeFilePath -Force
            }
            Set-Content -Path $noticeFilePath -Value $noticeFileContent -Force
        }

        # Clean up files older than 30 days
        if (Test-Path $downloadPaths) {
            Write-Output "Removing files older than 30 days from $downloadPaths..."
            Get-ChildItem $downloadPaths -Include * -Recurse | Where-Object { $_.LastWriteTime -lt $timeLimit -and $_.Name -ne $noticeFileName } | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    # Defragment profile disk
    Write-Output "Defragmenting profile disk on drive $driveLetter..."
    Optimize-Volume -DriveLetter $driveLetter -Defrag -Verbose

    # Compact disk using DISKPART
    Write-Output "Compacting profile disk on drive $driveLetter..."
    $diskpartScript = @"
select vdisk file="$VHDXFilePath"
compact vdisk
"@

    $diskpartScript | diskpart

    # Unmount VHDX
    Write-Output "Unmounting VHDX file: $VHDXFilePath..."
    Dismount-DiskImage $VHDXFilePath -ErrorAction SilentlyContinue
}

# Process VHDX files based on environment variables
if ($Target) {
    $targetFile = Join-Path $Path $Target
    if (Test-Path $targetFile) {
        Optimize-VHDX -VHDXFilePath $targetFile
    } else {
        Write-Output "Specified target file '$Target' does not exist."
    }
} else {
    $vhdxFiles = Get-ChildItem -Path "$Path\*.vhdx" -File
    if ($vhdxFiles.Count -eq 0) {
        Write-Output "No VHDX files found in the specified path: $Path"
    } else {
        if ($RandomPicks) {
            $randomFiles = $vhdxFiles | Get-Random -Count ($vhdxFiles.Count / 2)
            foreach ($file in $randomFiles) {
                Optimize-VHDX -VHDXFilePath $file.FullName
            }
        } else {
            $vhdxFiles | ForEach-Object {
                Optimize-VHDX -VHDXFilePath $_.FullName
            }
        }
    }
}

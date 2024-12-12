<#
.SYNOPSIS
    This script automates the process of installing Bluescreen Viewer, running it to generate a crash log, and uploading Minidump files to a Nextcloud WebDAV server.

.DESCRIPTION
    The script installs Bluescreen Viewer using Chocolatey, runs it to generate a crash log, and displays the log in the terminal.
    It then checks the local Minidump folder for dump files, uploads them to a specified Nextcloud WebDAV URL, and renames them with a "_sent" suffix after a successful upload.

.EXEMPLE
    NEXTCLOUD_WEBDAV_URL=https://nextcloud.XYZ.AB/public.php/webdav/
    NEXTCLOUD_TOKEN=SHARETOKEN

.NOTES
    Author: SAN
    Date: 02.12.24
    Dependencies: Chocolatey, Nextcloud public share
    #PUBLIC

.CHANGELOG

#>

# Step 1: Retrieve Nextcloud WebDAV URL and Token from environment variables
$nextcloudWebdavUrl = [System.Environment]::GetEnvironmentVariable("NEXTCLOUD_WEBDAV_URL")
$webdavUser = [System.Environment]::GetEnvironmentVariable("NEXTCLOUD_TOKEN")

# Exit the script if the Nextcloud WebDAV URL or token is not provided
if (-not $nextcloudWebdavUrl -or -not $webdavUser) {
    Write-Host "Error: Nextcloud WebDAV URL or token is not provided in environment variables."
    exit 1
}

# Variables (defined at the top for easy configuration)
$minidumpPath = "C:\Windows\Minidump"  # Path to Minidump folder
$hostname = (Get-WmiObject -Class Win32_ComputerSystem).Name  # Get the system hostname

# Bluescreen Viewer Installation Variables
$bluescreenViewerPath = "C:\Program Files (x86)\NirSoft\BlueScreenView\BlueScreenView.exe"
$bluescreenLogFile = "$env:temp\bluescreen_log.txt"  # Path to save Bluescreen log file

# Force TLS 1.2 for secure connection when uploading to WebDAV
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Step 2: Install Bluescreen Viewer using Chocolatey (silent installation)
Write-Host "Installing Bluescreen Viewer..."
choco install bluescreenview -y --no-progress | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installation failed. Continuing with script."
}

# Step 3: Run Bluescreen Viewer to generate the crash log and save it to a text file
Write-Host "Running Bluescreen Viewer to generate crash log..."
Start-Process $bluescreenViewerPath -ArgumentList "/stext $bluescreenLogFile" -Wait
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to run Bluescreen Viewer. Continuing with script."
}

# Step 4: Output the content of the crash log file to the terminal
Write-Host "Displaying crash logs..."
if (Test-Path $bluescreenLogFile) {
    Get-Content $bluescreenLogFile
} else {
    Write-Host "The crash log file does not exist."
}

# Step 5: Check if the Minidump directory exists and process the files
if (Test-Path $minidumpPath) {
    # Get all files in the Minidump directory, excluding those already marked as "_sent"
    $files = Get-ChildItem -Path $minidumpPath | Where-Object { $_.Name -notlike "*_sent*" }

    # Step 6: Loop through each Minidump file and upload to Nextcloud WebDAV
    foreach ($file in $files) {
        # Construct a new file name with the hostname at the beginning
        $newFileName = "$hostname" + "_" + $file.Name
        $uploadUrl = $nextcloudWebdavUrl + $newFileName  # Construct WebDAV URL for each file

        # Step 7: Prepare the authorization header for WebDAV (no password)
        $headers = @{
            "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${webdavUser}:")))"
            "X-Requested-With" = "XMLHttpRequest"
        }

        # Step 8: Upload the file to Nextcloud WebDAV
        try {
            Write-Host "Uploading $($file.Name) to $uploadUrl..."
            Invoke-WebRequest -Uri $uploadUrl -Method Put -InFile $file.FullName -Headers $headers -UseBasicParsing
            Write-Host "Successfully uploaded $newFileName"

            # Step 9: Rename the file by appending "_sent" after successful upload
            $fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $fileExtension = [System.IO.Path]::GetExtension($file.Name)
            $newSentName = "$fileBaseName`_sent$fileExtension"

            # Step 10: Rename the file to indicate it has been successfully sent
            Rename-Item -Path $file.FullName -NewName $newSentName
            Write-Host "Renamed $($file.Name) to $newSentName"
        } catch {
            Write-Host "Failed to upload $($file.Name): $_"
        }
    }
} else {
    Write-Host "Minidump folder not found!"
}

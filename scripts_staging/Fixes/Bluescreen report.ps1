<#
.SYNOPSIS
    This script automates the process of installing Bluescreen Viewer, running it to generate a crash log, and uploading Minidump files to a Nextcloud WebDAV server.

.DESCRIPTION
    The script installs Bluescreen Viewer using Chocolatey, runs it to generate a crash log, and displays the log in the terminal.
    It then checks the local Minidump folder for dump files, uploads them to a specified Nextcloud WebDAV URL, and renames them with a "_sent" suffix after a successful upload.

.EXEMPLE
    NEXTCLOUD_WEBDAV_URL=https://nextcloud.XYZ.AB/public.php/webdav/
    NEXTCLOUD_TOKEN=SHARETOKEN
    SITE_NAME={{site.name}}
    CLIENT_NAME={{client.name}}

.NOTES
    Author: SAN
    Date: 02.12.24
    Dependencies: Chocolatey, Nextcloud public share
    #PUBLIC

.CHANGELOG
    18.12.24 SAN Added site & client name to the uploaded file, added boot time to the report, moved dmp check
    08.01.25 SAN Remove error code in case of missing folder it is causing issues in case of false positive on failure runs

#>
# Step 1: Retrieve Nextcloud WebDAV URL, Token, Client Name, and Site Name from environment variables
$nextcloudWebdavUrl = [System.Environment]::GetEnvironmentVariable("NEXTCLOUD_WEBDAV_URL")
$webdavUser = [System.Environment]::GetEnvironmentVariable("NEXTCLOUD_TOKEN")
$clientName = [System.Environment]::GetEnvironmentVariable("CLIENT_NAME")
$siteName = [System.Environment]::GetEnvironmentVariable("SITE_NAME")

# Exit the script if the Nextcloud WebDAV URL or token is not provided
if (-not $nextcloudWebdavUrl -or -not $webdavUser) {
    Write-Host "Error: Nextcloud WebDAV URL or token is not provided in environment variables."
    exit 1
}

# Ensure WebDAV URL ends with a slash
if (-not $nextcloudWebdavUrl.EndsWith("/")) {
    $nextcloudWebdavUrl += "/"
}

# Variables (defined at the top for easy configuration)
$minidumpPath = "C:\Windows\Minidump"
$hostname = (Get-WmiObject -Class Win32_ComputerSystem).Name

# Check if the Minidump directory exists and contains any .dmp
if (-not (Test-Path $minidumpPath)) {
    Write-Error "Minidump folder not found!"
    exit
} elseif (-not (Get-ChildItem -Path $minidumpPath -Filter "*.dmp")) {
    Write-Error "No dump files found in Minidump folder!"
    exit
}

# Sanitize Client Name and Site Name to keep only a-z, 0-9, and spaces, then replace spaces with dashes
$sanitizePattern = "[^a-zA-Z0-9 ]"
$clientName = ($clientName -replace $sanitizePattern, "").Replace(" ", "-")
$siteName = ($siteName -replace $sanitizePattern, "").Replace(" ", "-")
$hostname = $hostname.Replace(" ", "-")  # Ensure hostname has no spaces

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
if (Test-Path $bluescreenViewerPath) {
    Start-Process $bluescreenViewerPath -ArgumentList "/stext $bluescreenLogFile" -Wait
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to run Bluescreen Viewer. Continuing with script."
    }
} else {
    Write-Host "Bluescreen Viewer executable not found. Skipping crash log generation."
}

# Step 4: Output the content of the crash log file to the terminal
if (Test-Path $bluescreenLogFile) {
    $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime | Get-Date -Format 'dd-MM-yyyy HH:mm:ss'
    Write-Host "Last 3 boot event:"
    try {
        $bootEvents = Get-WinEvent -LogName System -FilterXPath "*[System[EventID=6005]]" -ErrorAction Stop
        $bootEvents | Select-Object -ExpandProperty TimeCreated | Sort-Object -Descending | Select-Object -First 3
    } catch {
        Write-Host "An error occurred: $_"
    }
    Write-Host "Displaying crash logs..."
    Get-Content $bluescreenLogFile
} else {
    Write-Host "The crash log file does not exist."
}

# Step 5: Get all files in the Minidump directory, excluding those already marked as "_sent"
$files = Get-ChildItem -Path $minidumpPath -Filter "*.dmp" | Where-Object { $_.Name -notlike "*_sent*" }

# Step 6: Loop through each Minidump file and upload to Nextcloud WebDAV
foreach ($file in $files) {
    $newFileName = "$clientName`_$siteName`_$hostname`_$($file.Name)"
    $uploadUrl = $nextcloudWebdavUrl + $newFileName 

    # Step 7: Prepare the authorization header for WebDAV (no password)
    $headers = @{
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${webdavUser}:")))"
        "X-Requested-With" = "XMLHttpRequest"
    }

    # Step 8: Upload the file to Nextcloud WebDAV
    try {
        Write-Host "Uploading $($file.Name) to $uploadUrl..."
        $response = Invoke-WebRequest -Uri $uploadUrl -Method Put -InFile $file.FullName -Headers $headers -UseBasicParsing
        if ($response.StatusCode -eq 201 -or $response.StatusCode -eq 204) {
            Write-Host "Successfully uploaded $newFileName"

            # Step 9: Rename the file by appending "_sent" after successful upload
            $fileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $fileExtension = [System.IO.Path]::GetExtension($file.Name)
            $newSentName = "$fileBaseName`_sent$fileExtension"

            # Step 10: Rename the file to indicate it has been successfully sent
            Rename-Item -Path $file.FullName -NewName $newSentName
            Write-Host "Renamed $($file.Name) to $newSentName"
        } else {
            Write-Host "Unexpected response from server: $($response.StatusCode)"
        }
    } catch {
        Write-Host "Failed to upload $($file.Name): $_"
    }
}

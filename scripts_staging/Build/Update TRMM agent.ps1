<#
.SYNOPSIS
    Downloads and installs the latest or specified version of the Tactical RMM agent, with support for signed and unsigned downloads.

.DESCRIPTION
    This script retrieves the latest version of the Tactical RMM agent from GitHub or downloads a specified version based on the input environment variables. 
    It supports downloading a signed version using a provided token, or an unsigned version directly from GitHub. 
    If the specified version is set to "latest," the script fetches the most recent release information.
    Before downloading, it checks the locally installed version from the software list and skips the download if it matches the desired version.

.PARAMETER version
    Specifies the version to download. If set to "latest," the script retrieves the latest version available on GitHub. 
    This should be specified through the environment variable `version`.

.PARAMETER signedDownloadToken
    The token used for authenticated signed downloads. This should be set in the environment variable `trmm_sign_download_token`. 
    If this token is provided, the script will download the signed version.

.PARAMETER trmm_api_target
    The API target required for signed downloads. This should be specified in the environment variable `trmm_api_target`. 
    This is only necessary if using a signed download.

.EXEMPLE
    trmm_sign_download_token={{global.trmm_sign_download_token}}
    version=latest
    version=2.7.0
    trmm_api_target=api.exemple.com
    
.NOTES
    Author: SAN
    Date: 29.10.24
    #public

.CHANGELOG
    29.10.24 SAN Initial script with signed and unsigned download support.
    21.12.24 SAN updated the script to not require "issigned"
    22.12.24 SAN default to latest when no version is set

.TODO 
    integrate to our monthly update runs
    test if api target is really needed
    
#>
# Variables
$version = $env:version                  # Specify a version manually, or leave as "latest" to get the latest version from GitHub
$signedDownloadToken = $env:trmm_sign_download_token  # Token used for signed downloads only
$apiTarget = $env:trmm_api_target        # Environment variable for the API target URL

# Define GitHub API URL for the RMMAgent repository
$repoUrl = "https://api.github.com/repos/amidaware/rmmagent/releases/latest"

# Function to get the currently installed version of the Tactical RMM agent from the software list
function Get-InstalledVersion {
    $appName = "Tactical RMM Agent"  # Adjust if the application's display name differs left this in case whitelabel changes the name of the app
    $installedSoftware = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -like "*$appName*" }

    if ($installedSoftware) {
        return $installedSoftware.Version
    } else {
        # Check the uninstall registry key for a more complete list
        $uninstallKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        foreach ($key in $uninstallKeys) {
            $installedSoftware = Get-ItemProperty $key | Where-Object { $_.DisplayName -like "*$appName*" }
            if ($installedSoftware) {
                return $installedSoftware.DisplayVersion
            }
        }

        return $null
    }
}

try {
    # Set up headers for GitHub API request
    $headers = @{
        "User-Agent" = "PowerShell Script"
    }

    # If version is not set, default to "latest"
    if (-not $version) {
        $version = "latest"
    }

    # If version is set to "latest", fetch the latest release information from GitHub
    if ($version -eq "latest") {
        Write-Output "Fetching the latest version information from GitHub..."
        $response = Invoke-RestMethod -Uri $repoUrl -Headers $headers -Method Get -ErrorAction Stop
        $version = $response.tag_name.TrimStart('v')  # Remove 'v' prefix if exists
        Write-Output "Latest version found: $version"
    } else {
        Write-Output "Using specified version: $version"
    }

    # Check if the installed version matches the desired version
    $installedVersion = Get-InstalledVersion
    if ($installedVersion) {
        Write-Output "Installed version of 'Tactical RMM Agent': $installedVersion"
        if ($installedVersion -eq $version) {
            Write-Output "The installed version matches the desired version. No download required."
            exit 0
        } else {
            Write-Output "The installed version ($installedVersion) does not match the desired version ($version). Proceeding with download."
        }
    } else {
        Write-Output "'Tactical RMM Agent' is not installed on this system. Checking installed software..."
    }

    # Define the temp directory for downloading
    $tempDir = [System.IO.Path]::GetTempPath()
    $outputFile = Join-Path -Path $tempDir -ChildPath "tacticalagent-v$version.exe"

    # Determine the download URL based on the presence of $signedDownloadToken
    if ($signedDownloadToken) {
        if (-not $apiTarget) {
            Write-Output "Error: Missing API target for signed downloads. Exiting..."
            exit 1
        }

        # Download the signed agent using the token
        $downloadUrl = "https://agents.tacticalrmm.com/api/v2/agents?version=$version&arch=amd64&token=$signedDownloadToken&plat=windows&api=$apiTarget"
    } else {
        # Download the unsigned agent directly from GitHub releases
        $downloadUrl = "https://github.com/amidaware/rmmagent/releases/download/v$version/tacticalagent-v$version-windows-amd64.exe"
    }

    Write-Output "Downloading from: $downloadUrl"
    
    # Download the agent file
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile -ErrorAction Stop
        Write-Output "Download completed: $outputFile"
    } catch {
        Write-Output "Failed to download the agent. Error: $($_.Exception.Message)"
        exit 1
    }

    # Run the downloaded file in a new context (using cmd)
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $outputFile
    $processStartInfo.Arguments = "/VERYSILENT"
    $processStartInfo.UseShellExecute = $true  # Allows the executable to run independently
    $processStartInfo.CreateNoWindow = $true    # Prevents a new window from being created

    Write-Output "Starting installation..."

    # Start the process without attempting to cast the result
    try {
        [System.Diagnostics.Process]::Start($processStartInfo)
        Write-Output "Installation started. The process is running in the background."
    } catch {
        Write-Output "Failed to start the installation process. Error: $($_.Exception.Message)"
        exit 1
    }
} catch {
    # Handle unexpected errors with output
    Write-Output "An unexpected error occurred: $($_.Exception.Message)"
    exit 1
}

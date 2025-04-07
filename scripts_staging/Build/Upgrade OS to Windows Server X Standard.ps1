<#
.SYNOPSIS
This script performs an in-place upgrade of a Windows Server machine by downloading and extracting the ISO file from a specified Nextcloud share.

.DESCRIPTION
The script downloads the ISO from a Nextcloud share, verifies its checksum, extracts it using 7-Zip, and then initiates an in-place upgrade of the server.
The Nextcloud share URL format should be as follows:
https://nextcloud.xxx.xxx/s/xxxxxxxxx/download?path=%2F&files=
All keys are valid for initial installation and from https://learn.microsoft.com/en-us/windows-server/get-started/kms-client-activation-keys?tabs=server2016%2Cwindows1110ltsc%2Cversion1803%2Cwindows81

.EXAMPLE
    TARGETED_VERSION=2019
    Download_Source=https://nextcloud.xxx.xxx/s/xxxxxxxxx/download?path=%2F&files=


.NOTE
    Author: SAN
    Date: 14.11.24
    #Public

.CHANGELOG

    27.03.25 SAN Full code refactorisation for more locale support & checksum verification & transfer repo to a single NC share
    03.04.25 SAN exit if missing version
    07.04.25 SAN Added timestamps to messages

.TODO
    find solutions for automated DC server upgrades
    Add password on the nextcloud repo and make the script use it
    Find a way to use UUP to download the ISO of all windows versions
    
#>


# Windows Server Versions Metadata
$serverVersions = @{
    "2016" = @{
        "en" = @{
            "file" = "en_windows_server_2016_vl_x64_dvd_11636701.iso"
            "checksum" = "47919CE8B4993F531CA1FA3F85941F4A72B47EBAA4D3A321FECF83CA9D17E6B8" # pragma: allowlist-secret
            "licenseKey" = "WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY"
        }
        "fr" = @{
            "file" = "fr_windows_server_2016_vl_x64_dvd_11636729.iso"
            "checksum" = "81B809A9782C046A48D461AAEBFCD33D07A566C5A990373D0A36CDA1E08EA6F0" # pragma: allowlist-secret
            "licenseKey" = "WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY"
        }
    }
    "2019" = @{
        "en" = @{
            "file" = "en-us_windows_server_2019_x64_dvd_f9475476.iso"
            "checksum" = "EA247E5CF4DF3E5829BFAAF45D899933A2A67B1C700A02EE8141287A8520261C" # pragma: allowlist-secret
            "licenseKey" = "N69G4-B89J2-4G8F4-WWYCC-J464C"
        }
        "fr" = @{
            "file" = "fr-fr_windows_server_2019_x64_dvd_f6f6acf6.iso"
            "checksum" = "E0C6958E94F41163AA1EA9500825B8523136E1B8C5FC03CB7E3900858C7134AD" # pragma: allowlist-secret
            "licenseKey" = "N69G4-B89J2-4G8F4-WWYCC-J464C"
        }
    }
    "2022" = @{
        "en" = @{
            "file" = "en-us_windows_server_2022_updated_nov_2024_x64_dvd_4e34897c.iso"
            "checksum" = "0C388FE9D0A524AC603945F5CFFB7CC600A73432BCCCEA3E95274BF851973C96" # pragma: allowlist-secret
            "licenseKey" = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H" 
        }
        "fr" = @{
            "file" = "fr-fr_windows_server_2022_updated_nov_2024_x64_dvd_4e34897c.iso"
            "checksum" = "CCF7FF49503C652E59EE87DE5E66260739F5B20BFB448B3D68411455C291F423" # pragma: allowlist-secret
            "licenseKey" = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"
        }
    }
    "2025" = @{
        "en" = @{
            "file" = "en-us_windows_server_2025_x64_dvd_b7ec10f3.iso"
            "checksum" = "854109E1F215A29FC3541188297A6CA97C8A8F0F8C4DD6236B78DFDF845BF75E" # pragma: allowlist-secret
            "licenseKey" = "TVRH6-WHNXV-R9WG3-9XRFY-MY832"
        }
        "fr" = @{
            "file" = "fr-fr_windows_server_2025_x64_dvd_bd6be507.iso"
            "checksum" = "45384960A3F430D26454955D1198A6E38E7AA98C9E3906AC1AE9367229C103D0" # pragma: allowlist-secret
            "licenseKey" = "TVRH6-WHNXV-R9WG3-9XRFY-MY832"
        }
    }
}


# Function to compute SHA256 checksum
function Get-FileChecksum {
    param ([string]$filePath)
    $hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
    $fileStream = [System.IO.File]::OpenRead($filePath)
    $checksum = [BitConverter]::ToString($hashAlgorithm.ComputeHash($fileStream)).Replace("-", "").ToUpper()
    $fileStream.Close()
    return $checksum
}

# Function to verify the checksum of the downloaded file
function Verify-Checksum {
    param ([string]$filePath, [string]$expectedChecksum)
    if (-not (Test-Path $filePath)) { return $false }
    return (Get-FileChecksum -filePath $filePath) -eq $expectedChecksum
}

# Function to check requirements
function Check-Requirements {
    param ([string]$targetedVersion, [string]$baseUrl)

    if (-not $targetedVersion -or -not $baseUrl) { Write-Log "Missing parameters. Exiting."; exit 1 }
    if (-not $serverVersions.ContainsKey($targetedVersion)) { Write-Log "Invalid version: $targetedVersion. Exiting."; exit 1 }

    $systemLocale = (Get-WinSystemLocale).Name.Substring(0,2).ToLower()
    if (-not $serverVersions[$targetedVersion].ContainsKey($systemLocale)) { Write-Log "Unsupported language: $systemLocale. Exiting."; exit 1 }

    $sevenZipPath = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
    if (-not $sevenZipPath -and -not (Test-Path ($sevenZipPath = "C:\Program Files\7-Zip\7z.exe"))) { Write-Log "7-Zip not found. Exiting."; exit 1 }

    if ((Get-PSDrive C).Free -lt 12GB) { Write-Log "Not enough disk space. Exiting."; exit 1 }

    return $systemLocale, $sevenZipPath
}

# Function to write log with timestamp
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $message"
}

# Function to perform in-place upgrade
function Perform-InPlaceUpgrade {
    param ([string]$setupPath, [string]$licenseKey)
    $upgradeArgs = "/auto upgrade /quiet /dynamicupdate disable /imageindex 2 /eula accept /pkey $licenseKey"
    Write-Log "Starting in-place upgrade..."
    Start-Process -FilePath $setupPath -ArgumentList $upgradeArgs -Wait -NoNewWindow
    Write-Log "Upgrade process initiated."
}

# Main Execution
$targetedVersion = [Environment]::GetEnvironmentVariable("TARGETED_VERSION")
$baseUrl = $env:Download_Source

# Perform requirements check
$checkResult = Check-Requirements -targetedVersion $targetedVersion -baseUrl $baseUrl
$language = $checkResult[0]
$sevenZipPath = $checkResult[1]

# Fetch metadata
$metadata = $serverVersions[$targetedVersion][$language]
$isoFile = "C:\\Windows\\Temp\\$($metadata.file)"
$extractFolder = "C:\\Windows\\Temp\\windows_server_extract"

# Validate or download ISO
if (!(Verify-Checksum -filePath $isoFile -expectedChecksum $metadata.checksum)) {
    Write-Log "Downloading ISO..."
    Invoke-WebRequest -Uri "$baseUrl$($metadata.file)" -OutFile $isoFile
    if (!(Verify-Checksum -filePath $isoFile -expectedChecksum $metadata.checksum)) {
        Write-Log "Checksum verification failed. Exiting."
        exit 1
    }
}

# Clean and extract ISO
if (Test-Path $extractFolder) { Remove-Item -Recurse -Force $extractFolder }
Write-Log "Extracting ISO..."
Start-Process -FilePath $sevenZipPath -ArgumentList "x `"$isoFile`" -o`"$extractFolder`" -y" -Wait

# Delete ISO file to free up space
Write-Log "Deleting ISO file to free up space..."
Remove-Item -Path $isoFile -Force

# Locate and execute setup.exe
$setupPath = Get-ChildItem -Path $extractFolder -Recurse -Filter "setup.exe" -File | Select-Object -First 1
if ($setupPath) {
    Perform-InPlaceUpgrade -setupPath $setupPath.FullName -licenseKey $metadata.licenseKey
} else {
    Write-Log "setup.exe not found. Exiting."
    exit 1
}


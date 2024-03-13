<#
.SYNOPSIS
This script deletes cookies from common web browsers (Chrome, Firefox, Edge) on Windows systems. It targets the default locations where these browsers store their cookies. This operation is irreversible; ensure that any important data is backed up before running this script.

.DESCRIPTION
The script iterates over the predefined paths for Chrome, Firefox, and Edge cookie storage, removing the cookies stored by these browsers. For Firefox, which may have multiple profiles, the script locates and clears cookies for each profile found.

.PARAMETERS
None.

When deploying this script via Tactical RMM, ensure it is executed as a user to correctly locate and access the browser profiles.

#>

# Function to delete cookies for a specific browser
function Clear-Cookies {
    param (
        [string]$browserName,
        [string[]]$paths
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Output "Deleting cookies for $browserName from $path"
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Output "$browserName cookies not found at $path"
        }
    }
}

# Specify user profile paths (you may need to adjust these paths)
$userProfile = [Environment]::GetFolderPath('UserProfile')
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')

# Paths where browsers typically store cookies
$chromeCookiePaths = @("$localAppData\Google\Chrome\User Data\Default\Cookies")
$edgeCookiePaths = @("$localAppData\Microsoft\Edge\User Data\Default\Cookies")
$firefoxProfilesPath = "$userProfile\AppData\Roaming\Mozilla\Firefox\Profiles"

# Clear cookies for Chrome
Clear-Cookies -browserName "Chrome" -paths $chromeCookiePaths

# Clear cookies for Edge
Clear-Cookies -browserName "Edge" -paths $edgeCookiePaths

# Clear cookies for Firefox (handles multiple profiles)
if (Test-Path $firefoxProfilesPath) {
    $firefoxProfiles = Get-ChildItem -Path $firefoxProfilesPath -Directory
    foreach ($profile in $firefoxProfiles) {
        $cookiesPath = Join-Path -Path $profile.FullName -ChildPath "cookies.sqlite"
        Clear-Cookies -browserName "Firefox" -paths @($cookiesPath)
    }
} else {
    Write-Output "Firefox profiles not found at $firefoxProfilesPath"
}

Write-Output "Cookie deletion process completed."

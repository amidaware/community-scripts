<#
.SYNOPSIS
    A PowerShell script to implement a kill switch mechanism for Tactical RMM using scheduled tasks and DNS TXT records.

.DESCRIPTION
    This script sets up a kill switch by creating a scheduled task that runs hourly. 
    It checks DNS TXT records for specific flags (`stop=true` or `uninstall=true`) and executes corresponding actions like stopping services or uninstalling Tactical RMM. 
    The script is designed as a safeguard in case the RMM system behaves unexpectedly or goes rogue, allowing administrators to disable or uninstall it remotely and independently.

.PARAMETER killswitchdomain
    The domain used to resolve the DNS TXT records containing kill switch flags. 
    This can be specified through the environment variable `killswitchdomain`.

.PARAMETER companyfolder
    The folder path where the script file (`RMM_Kill_Switch.ps1`) will be saved.
    This can be specified through the environment variable `companyfolder`.

.EXAMPLE
    killswitchdomain=kill.alltacticalagents.example.com
    companyfolder=C:\CompanyFolder
    companyfolder={{global.Company_folder_path}}

.NOTES
    Author: SAN
    Date: 01.01.2024
    #public

.CHANGELOG
    12.06.25 SAN Fixed var passtrough issue and hidden the file
    
.TODO
    Integrate this script into the deployment process.
    Cleanup the code
    split script content to snippet 
    add company name folder for task
    hide script
    scripts subfolder setup ?
    hide error when first setup

#>



# Retrieve the domain and path from environment variables
$domain = [System.Environment]::GetEnvironmentVariable('killswitchdomain')
$envVar = [System.Environment]::GetEnvironmentVariable('companyfolder')

if (-not $domain) {
    Write-Host "Environment variable 'killswitchdomain' not found."
    exit 1
}

if (-not $envVar) {
    Write-Host "Environment variable 'companyfolder' not found."
    exit 1
}

$scriptPath = Join-Path -Path $envVar -ChildPath "RMM_Kill_Switch.ps1"
$taskName = "RMM_Kill_Switch"

# Delete the existing task if it exists
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

$scriptContent = @'
function ExecuteStopBranch {
    Stop-Service -Name "tacticalrmm" -Force
    Get-Process -Name "tacticalrmm" -ErrorAction SilentlyContinue | Stop-Process -Force
    Stop-Service -Name "Mesh Agent" -Force
    Get-Process -Name "MeshAgent" -ErrorAction SilentlyContinue | Stop-Process -Force
}

function ExecuteUninstallBranch {
    Start-Process -FilePath "C:\Program Files\TacticalAgent\unins000.exe" -ArgumentList "/VERYSILENT" -Wait
}

$record = Resolve-DnsName -Name "__DOMAIN_PLACEHOLDER__" -Type "TXT" -ErrorAction SilentlyContinue
if ($record) {
    $txtData = $record | Select-Object -ExpandProperty Strings
    $foundStop = $txtData -match "stop=true"
    $foundUninstall = $txtData -match "uninstall=true"

    if (-not $foundStop -and -not $foundUninstall) {
        Write-Host "Neither 'stop=true' nor 'uninstall=true' found in the TXT record for __DOMAIN_PLACEHOLDER__."
    }
    elseif ($foundStop) {
        ExecuteStopBranch
    }
    elseif ($foundUninstall) {
        ExecuteUninstallBranch
    }
} else {
    Write-Host "TXT record for __DOMAIN_PLACEHOLDER__ not found."
}
'@

# Replace placeholder with actual domain due to powershell shenanigans
$scriptContent = $scriptContent -replace '__DOMAIN_PLACEHOLDER__', $domain


# Save the script content to the file
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
#Set-ItemProperty -Path $scriptPath -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)

# Create a scheduled task to run the script hourly and daily
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# Specify hourly triggers for 24 hours with random minutes
$triggers = @()
for ($hour = 0; $hour -lt 24; $hour++) {
    $randomMinutes = Get-Random -Minimum 0 -Maximum 59
    $triggerHourly = New-ScheduledTaskTrigger -At (Get-Date).AddHours($hour).AddMinutes($randomMinutes) -Daily
    $triggers += $triggerHourly
}

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -Description "Task to run the Tactical RMM Kill Switch script hourly and daily." -User "SYSTEM"
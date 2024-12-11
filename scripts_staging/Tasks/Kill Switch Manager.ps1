<#
.SYNOPSIS
    A PowerShell script to implement a kill switch mechanism for Tactical RMM using scheduled tasks and DNS TXT records.

.DESCRIPTION
    This script sets up a kill switch by creating a scheduled task that runs hourly. 
    It checks DNS TXT records for specific flags (`stop=true` or `uninstall=true`) and executes corresponding actions like stopping services or uninstalling Tactical RMM. 
    The script is designed as a safeguard in case the RMM system behaves unexpectedly or goes rogue, allowing administrators to disable or uninstall it remotely and securely.

.PARAMETER killswitchdomain
    The domain used to resolve the DNS TXT records containing kill switch flags. 
    This can be specified through the environment variable `killswitchdomain`.

.PARAMETER companyfolder
    The folder path where the script file (`RMM_Kill_Switch.ps1`) will be saved.
    This can be specified through the environment variable `companyfolder`.

.EXAMPLE
    $env:killswitchdomain="example.com"
    $env:companyfolder="C:\CompanyFolder"

    Run the script to set up the kill switch for Tactical RMM.

.NOTES
    Author: SAN
    Date: ???
    #public

.CHANGELOG


.TODO
    Integrate this script into the deployment process.
    Add global var to var
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

# Script content to save in the file
$scriptContent = @"
# Function to execute the stop branch
function ExecuteStopBranch {
    # Stop Service name: tacticalrmm
    Stop-Service -Name "tacticalrmm" -Force
    
    # Kill all tacticalrmm.exe processes
    Get-Process -Name "tacticalrmm" | Stop-Process -Force
    
    # Stop Service name: Mesh Agent
    Stop-Service -Name "Mesh Agent" -Force
    
    # Kill all MeshAgent.exe processes
    Get-Process -Name "MeshAgent" | Stop-Process -Force
}

# Function to execute the uninstall branch
function ExecuteUninstallBranch {
    # Execute the uninstall command silently
    #Start-Process -FilePath "C:\Program Files\TacticalAgent\unins000.exe" -ArgumentList "/VERYSILENT" -Wait
}

# Resolve the TXT record
\$record = Resolve-DnsName -Name "$domain" -Type "TXT"

# Check if the record was found
if (\$record) {
    \$txtData = \$record | Select-Object -ExpandProperty Strings
    \$foundStop = \$txtData -match "stop=true"
    \$foundUninstall = \$txtData -match "uninstall=true"

    if (-not \$foundStop -and -not \$foundUninstall) {
        # Neither stop=true nor uninstall=true found
        Write-Host "Neither 'stop=true' nor 'uninstall=true' found in the TXT record for $domain."
        # Add your code for the default case here
    }
    elseif (\$foundStop) {
        # Branch for stop=true
        ExecuteStopBranch
    }
    elseif (\$foundUninstall) {
        # Branch for uninstall=true
        ExecuteUninstallBranch
    }
} else {
    Write-Host "TXT record for $domain not found."
}
"@

# Save the script content to the file
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

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
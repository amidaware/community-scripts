<#
.SYNOPSIS
    Stop and disable specified ASUS services

.DESCRIPTION
    This script stops and disables a list of specified ASUS services on the local machine.
    It loops through each service name provided, attempts to stop the service, and then disables it.
    The script outputs the status of each operation.

.EXAMPLE
    "asusappservice", "asusoptimization", "ASUSSoftwareManager", "ASUSSwitch", "ASUSSystemAnalysis", "ASUSSystemDiagnosis"

.NOTES
    v1.0 7/17/2024 silversword411 Initial release Get rid of that ASUS crap that installs because of Armoury-crate autoinstaller that's enabled in BIOS
#>

# Define the variable containing the service names
$serviceNames = "asusappservice", "asusoptimization", "ASUSSoftwareManager", "ASUSSwitch", "ASUSSystemAnalysis", "ASUSSystemDiagnosis"

# Loop through each service name in the variable
foreach ($serviceName in $serviceNames) {
    # Stop the service
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    
    # Disable the service
    Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
    
    # Output the status of the operation
    if ((Get-Service -Name $serviceName).Status -eq 'Stopped') {
        Write-Output "$serviceName has been stopped and disabled successfully."
    }
    else {
        Write-Output "Failed to stop and disable $serviceName."
    }
}
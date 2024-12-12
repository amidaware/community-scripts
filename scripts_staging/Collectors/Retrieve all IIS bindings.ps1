<#
.SYNOPSIS
    This script retrieves IIS bindings, extracts and sorts unique domain names from the bindings.

.DESCRIPTION
    The script imports the WebAdministration module, retrieves all IIS bindings, 
    and extracts unique domain names from the binding information. 
    The script excludes wildcard bindings and invalid domain names. 
    It then outputs the sorted list of unique domain names, with optional debugging information if the debug flag is set.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG


.TODO
    set debug flag in env
    more gracefully handle execution on non-iis devices
#>


# Set the debug flag
$debug = 0

# Import the WebAdministration module
Import-Module WebAdministration

# Retrieve all IIS bindings
$bindings = Get-WebBinding

# Output the initial bindings for debugging
if ($debug -eq 1) {
    Write-Output "Initial Bindings:"
    $bindings | ForEach-Object { Write-Output $_ }
}

# Create a hash table to store unique domain names
$uniqueDomains = @{}

# Process each binding
foreach ($binding in $bindings) {
    $bindingInformation = $binding.bindingInformation
    $hostname = $bindingInformation -replace ".*:(.*?)(:\d+)?$", '$1'  # Extract only the domain part
    
    # Only add if the hostname is not empty, not a wildcard, and is a valid domain name
    if ($hostname -ne "" -and $hostname -ne "*" -and $hostname -match '^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$') {
        $uniqueDomains[$hostname] = $null
    }
}

# Output the unique domain names for debugging
if ($debug -eq 1) {
    Write-Output "Unique Domain Names:"
    $uniqueDomains.Keys | ForEach-Object { Write-Output $_ }
}

# Sort unique domain names alphabetically
$sortedDomains = $uniqueDomains.Keys | Sort-Object

# Output the sorted unique domain names
$sortedDomains | ForEach-Object { Write-Output $_ }
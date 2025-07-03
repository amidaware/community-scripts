<#
.SYNOPSIS
    Updates Chocolatey package sources by removing existing repositories and adding new ones with specified priorities.

.DESCRIPTION
    This script removes the specified Chocolatey package sources and adds new sources based on environment variables. 
    It sets the priority for the new source to a specified value and ensures that the default Chocolatey source is added with a lower priority or removed.

.EXAMPLE 
    NEW_URL="https://myrepo.com/chocolatey/"
    NEW_NAME="myrepo"
    keepDefaultRepo=0
   
.NOTES
    Author: SAN
    Date: 01.01.2024
    #public

.CHANGELOG
    SAN 11.12.24 Moved new info to env
    SAN 03.05.25 Added a flag to keep or not the default repo
    SAN 18.06.25 Added outputs
    
#>

$newUrl = $env:NEW_URL
$newPriority = 5
$newName = $env:NEW_NAME

$defaultUrl = "https://chocolatey.org/api/v2/"
$defaultPriority = 10
$defaultName = "chocolatey"

# Default to keeping the default repo unless explicitly set to "0"
$keepDefaultRepo = ($env:keepDefaultRepo -ne '0')

# Always remove both sources to ensure clean state and updated priority
Write-Output "Removing Chocolatey source: $newName (if exists)"
choco source remove -n $newName -y

Write-Output "Removing Chocolatey source: $defaultName (if exists)"
choco source remove -n $defaultName -y

# Add the new internal Chocolatey repository
Write-Output "Adding new Chocolatey source: $newName with URL $newUrl and priority $newPriority"
choco source add -n $newName -s $newUrl --priority $newPriority

# Conditionally re-add the default repository
if ($keepDefaultRepo) {
    Write-Output "Re-adding default Chocolatey source: $defaultName with priority $defaultPriority"
    choco source add -n $defaultName -s $defaultUrl --priority $defaultPriority
} else {
    Write-Output "Skipping re-adding default Chocolatey source"
}

<#
.SYNOPSIS
    Updates Chocolatey package sources by removing existing repositories and adding new ones with specified priorities.

.DESCRIPTION
    This script removes the specified Chocolatey package sources and adds new sources based on environment variables. It sets the priority for the new source to a specified value and ensures that the default Chocolatey source is added with a lower priority.

.EXAMPLE 
    NEW_URL="https://myrepo.com/chocolatey/"
    NEW_NAME="myrepo"
   
.NOTES
    Author: SAN
    Date: 01.01.2024
    #public

.CHANGELOG
    SAN 11.12.24 Moved new info to env


#>

$newUrl = $env:NEW_URL
$newPriority = 5
$newName = $env:NEW_NAME

$defaultUrl = "https://chocolatey.org/api/v2/"
$defaultPriority = 10
$defaultName = "chocolatey"

# Remove settings
choco source remove -n $defaultName -y
choco source remove -n $newName -y

# Add the new Chocolatey repository with the specified priority
choco source add -n $newName -s $newUrl --priority $newPriority
# Add the default Chocolatey repository with a low priority
choco source add -n $defaultName -s $defaultUrl --priority $defaultPriority

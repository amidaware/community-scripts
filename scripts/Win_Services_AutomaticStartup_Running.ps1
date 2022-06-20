###
# Author: Dave Long <dlong@cagedata.com>
# Date: 2021-05-12
#
# Gets a list of all services that have Startup Type set to Automatic
# and are currently not running. Then attempts to start them. 
#
# Note: A service that is set to Automatic and is not running is in
# some cases the correct behavior.
###

# To not automatically try to start all non-running automatic services
# change the following variable value to $false
$Start = $true

$Services = Get-Service | `
    Where-Object { $_.StartType -eq "Automatic" -and $_.Status -ne "Running" }

$Services | Format-Table

if ($Start) { $Services | Start-Service }

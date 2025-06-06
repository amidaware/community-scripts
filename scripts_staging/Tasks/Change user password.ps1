<#
.SYNOPSIS
    This script changes the password for the user to a randomly generated  password.

.DESCRIPTION
    The script defines a function to generate a random password and then sets the generated password for the specified user.

.NOTES
    Author: SAN
    Date: 01.01.24
    Dependencies:
        GeneratedPassphrase snippet
    #public
    
.CHANGELOG
    06.06.25 SAN added not allow to change the password on non primary DC it causes conflicts if run on multiple DC
    
.TODO
    move param to env
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$username
)

# Check if the machine is not a Primary Domain Controller
# this script should not run on multiple DC as it would cause syncronisation issues so for the sake of simplicity it's only allowed to run on PDC
$domainRole = (Get-WmiObject Win32_ComputerSystem).DomainRole
$isDomainController = $domainRole -ge 4  # 4 = Backup DC, 5 = Primary DC
if ($isDomainController) {
    try {
        Write-Host "Domain Controller detected"
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $pdc = $domain.PdcRoleOwner.Name.Split('.')[0]
        $localComputer = $env:COMPUTERNAME

        if ($pdc -ine $localComputer) {
            Write-Host "Not the Primary DC"
            exit 0
        }
        Write-Host "Primary DC detected"
    } catch {
        Write-Host "Error determining PDC role. Aborting."
        exit 1
    }
}

# Snippet for passphrase
{{GeneratedPassphrase}}

# Set the new password for the user
net user $username $GeneratedPassphrase

# Check if the password change was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "$GeneratedPassphrase"
} else {
    Write-Host "Password change for $username failed."
    exit 1
}

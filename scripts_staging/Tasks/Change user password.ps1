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
    
.TODO
    Do not allow to change the password on non primary DC it causes conflicts
    move param to env
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$username
)

#Call snippet
{{GeneratedPassphrase}}
$newPassword = $GeneratedPassphrase

# Set the new password for the user
net user $username $newPassword

# Check if the password change was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "$newPassword"
} else {
    Write-Host "Password change for $username failed. Please check for errors."
    exit 1
}
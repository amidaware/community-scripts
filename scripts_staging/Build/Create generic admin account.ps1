<#
.SYNOPSIS
    This script checks if an admin user exists, and if so, changes the password and ensures the user is added to the Administrators group. 

.DESCRIPTION
    The script retrieves the admin username from the environment variable `adminusername` and generates a passphrase. 
    It checks if the user exists on the system, then either updates the password for an existing user or creates the user if they do not exist. 
    It also ensures the user is added to both the 'Administrators' and 'Administrateurs' local groups and disables the password expiration.

.PARAMETER adminusername
    The environment variable `adminusername` should be set with the desired username for the admin account.

.EXAMPLE
    adminusername=adminUser    

.NOTES
    Author: SAN
    Date: 01.01.24
    Dependencies:
        GeneratedPassphrase snippet
    #public

.CHANGELOG
    


#>


{{GeneratedPassphrase}}

# Get admin username and password
$adminUsername = $env:adminusername
$adminPassword = $GeneratedPassphrase

# Check if the admin username is provided
if (-not $adminUsername) {
    Write-Output "adminusername environment variable is not set. Exiting script."
    exit 1
}

# Check if the user already exists
$existingUser = & net user $adminUsername 2>&1
if ($LASTEXITCODE -eq 0) {
    # User already exists
    Write-Output "The user '$adminUsername' already exists."
    try {
        # Change password
        & net user $adminUsername $adminPassword
        & wmic UserAccount where "Name='$adminUsername'" set PasswordExpires=False
        & net localgroup Administrators $adminUsername /add
        & net localgroup Administrateurs $adminUsername /add
        Write-Output "The password for user '$adminUsername' has been changed."
    }
    catch {
        Write-Output "Failed to change the password for user '$adminUsername'."
    }
}
else {
    # User doesn't exist
    Write-Output "The user '$adminUsername' does not exist."
    try {
        # Create user
        & net user $adminUsername $adminPassword /add /Y
        Write-Output "The user '$adminUsername' has been created with the password '$adminPassword'."
        & net localgroup Administrators $adminUsername /add
        & net localgroup Administrateurs $adminUsername /add
        Write-Output "The user '$adminUsername' has been added to the Administrators group."
        & wmic UserAccount where "Name='$adminUsername'" set PasswordExpires=False
    }
    catch {
        Write-Output "Failed to create the user '$adminUsername'."
    }
}
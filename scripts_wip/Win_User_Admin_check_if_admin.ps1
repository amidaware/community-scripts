<#
.SYNOPSIS
    Reports if the currently logged-in interactive user has local administrator rights.
    This script is designed to be run from the SYSTEM account.

.DESCRIPTION
    When run as SYSTEM, the script first identifies the user who is actively
    logged into the console session. It then uses the reliable ADSI provider to
    query the local 'Administrators' group and checks if the detected user is a member.

    This revised version avoids potential name resolution errors encountered with the
    [System.Security.Principal.WindowsIdentity] .NET class when run as SYSTEM.

.NOTES
    v1 2025-7-22 silversword411 initial release
#>
[CmdletBinding()]
param()

# Suppress errors for the initial check in case no one is logged in
$ErrorActionPreference = 'SilentlyContinue'

# --- Step 1: Find the currently logged-in user from the SYSTEM context ---
Write-Verbose "Querying Win32_ComputerSystem to find the interactive user..."
$loggedInUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
$ErrorActionPreference = 'Continue' # Reset error preference

# --- Step 2: Check if a user was found ---
if ([string]::IsNullOrWhiteSpace($loggedInUser)) {
    Write-Output "Status: No interactive user is currently logged in to the console."
    exit 0
}

# The user is typically returned as "DOMAIN\user" or "COMPUTERNAME\user".
# We only need the username part for the group check.
$usernameOnly = $loggedInUser.Split('\')[-1]
Write-Output "Detected logged-in user: $loggedInUser (Checking for account: $usernameOnly)"


# --- Step 3 (Revised): Check group membership using ADSI ---
try {
    # Define the well-known name for the local Administrators group
    $adminGroupName = "Administrators"

    # Use the ADSI provider to connect to the local Administrators group.
    # The "WinNT://" provider is used for local machine resources.
    # The "." represents the local computer.
    $group = [ADSI]"WinNT://./$adminGroupName,group"

    # Get all members of the group.
    $members = $group.psbase.Invoke("Members") | ForEach-Object {
        # For each member object, get its 'Name' property
        $_.GetType().InvokeMember("Name", "GetProperty", $null, $_, $null)
    }

    # Now, check if the username is in the list of administrator members.
    # We use the username part we extracted earlier ($usernameOnly).
    if ($members -contains $usernameOnly) {
        Write-Output "Result: The user '$loggedInUser' IS an Administrator."
        $host.SetShouldExit(1)
    }
    else {
        Write-Output "Result: The user '$loggedInUser' is NOT an Administrator."
        # You could exit with a specific code, e.g., exit 0 for "Not Admin"
    }
}
catch {
    Write-Error "An error occurred while checking Administrators group membership."
    Write-Error "Error details: $($_.Exception.Message)"
    # Exit with an error code
    exit 99
}
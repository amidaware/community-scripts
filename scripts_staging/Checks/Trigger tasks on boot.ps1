<#
.SYNOPSIS
    Exits with code 1 if automation should trigger (key does not exist); exits with 0 otherwise.

.DESCRIPTION
    This script uses a volatile registry key to determine whether it has already run in the current boot cycle.
    If the key already exists (i.e., automation has triggered before in this boot), the script exits with code 0.
    If the key does not exist (i.e., first run since boot), it creates the key and exits with code 66 to trigger on failure tasks.

    This approach was implemented as a workaround for TacticalRMM's lack of native "on-boot" task support.
    It enables TRMM tasks to detect the key’s lack of existence and act accordingly by triggering automations on failure of the check.

    Informational exit code should be set to 66 on the check.

.NOTES
    Author: SAN
    Date: 08.05.25
    #public
    Can't have any exit code on error in this script by nature otherwise it would trigger stuff left right and center.

.CHANGELOG
    08.05.25 SAN added check to avoid runing C when not needed to help with runtime and better outputs
    08.05.25 SAN optimised C code and cleaned exit codes

#>

$subKey = "SOFTWARE\\TacticalRMM\\BootTrigger"
[string]$msg = $null
$ExitCreated = 66
$ExitError = 0
$ExitOK = 0

# Check if the registry key exists
$regKeyExists = Test-Path "HKLM:\$subKey"

if ($regKeyExists) {
    # Key already exists, proceed with no action
    Write-Output "OK: Already triggered this boot"
    exit $ExitOK 
} else {
    # Key doesn't exist, load and execute C# code to create the volatile registry key
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class VolatileRegistry
{
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    public static extern int RegCreateKeyEx(
        UIntPtr hKey,
        string lpSubKey,
        int Reserved,
        string lpClass,
        uint dwOptions,
        int samDesired,
        IntPtr lpSecurityAttributes,
        out IntPtr phkResult,
        out int lpdwDisposition
    );

    [DllImport("advapi32.dll")]
    public static extern int RegCloseKey(IntPtr hKey);

    public static readonly UIntPtr HKEY_LOCAL_MACHINE = (UIntPtr)0x80000002;
    public const uint REG_OPTION_VOLATILE = 0x00000001;
    public const int KEY_ALL_ACCESS = 0xF003F;
    public const int KEY_WOW64_64KEY = 0x0100;

    public static bool CreateVolatileKey(string subKey, out string message)
    {
        IntPtr hKey;
        int disposition;

        int result = RegCreateKeyEx(
            HKEY_LOCAL_MACHINE,
            subKey,
            0,
            null,
            REG_OPTION_VOLATILE,
            KEY_ALL_ACCESS | KEY_WOW64_64KEY,
            IntPtr.Zero,
            out hKey,
            out disposition
        );

        if (result == 0)
        {
            message = string.Format("OK: Registry key created (disposition: {0}).", disposition);
            RegCloseKey(hKey);
            return true;
        }
        else
        {
            message = string.Format("KO: Failed to create registry key. Error code: {0}", result);
            return false;
        }
    }
}

"@
    try {
        # Run the C# code to create the volatile registry key
        $created = [VolatileRegistry]::CreateVolatileKey($subKey, [ref]$msg)

        Write-Output $msg

        if ($created -and ($msg -match 'OK')) {
            # First run since boot, and the message says OK — trigger automation
            exit $ExitCreated
        } else {
            # Key creation failed
            Write-Error "Failed to create the key"
            exit $ExitError
        }
    } catch {
        Write-Error "An unexpected error occurred: $_"
        exit $ExitError
    }
}
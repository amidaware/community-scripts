<#
.SYNOPSIS
    Exits with code 1 if automation should trigger (key does not exist); exits with 0 otherwise.

.DESCRIPTION
    This script uses a volatile registry key to determine whether it has already run in the current boot cycle.
    If the key already exists (i.e., automation has triggered before in this boot), the script exits with code 0.
    If the key does not exist (i.e., first run since boot), it creates the key and exits with code 1 to trigger on failure tasks.

    This approach was implemented as a workaround for TacticalRMM's lack of native "on-boot" task support.
    It enables TRMM tasks to detect the key’s lack of existence and act accordingly by triggering automations on failure of the check.

.NOTES
    Author: SAN
    Date: 08.05.25
    #public

.TODO
    Better outputs

#>



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

    public static UIntPtr HKEY_LOCAL_MACHINE = (UIntPtr)0x80000002;
    public const uint REG_OPTION_VOLATILE = 0x00000001;
    public const int KEY_ALL_ACCESS = 0xF003F;
    public const int KEY_WOW64_64KEY = 0x0100;

    public static bool CreateVolatileKey(string subKey, out string message)
    {
        IntPtr hKey;
        int disposition;
        try
        {
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

            message = string.Format("RegCreateKeyEx returned: {0}, disposition: {1}", result, disposition);

            if (result != 0)
            {
                throw new System.Exception("Failed to create registry key.");
            }

            return disposition == 1; // Key was created (disposition == 1)
        }
        catch (System.Exception ex)
        {
            message = "Error: " + ex.Message;
            return false;
        }
    }
}
"@

$subKey = "SOFTWARE\\TacticalRMM\\BootTrigger"
[string]$msg = $null

try {
    $created = [VolatileRegistry]::CreateVolatileKey($subKey, [ref]$msg)

    Write-Output $msg

    if ($created) {
        # First run since boot — trigger automation
        exit 1
    } else {
        # Already triggered this boot — do nothing
        exit 0
    }
} catch {
    Write-Error "An unexpected error occurred: $_"
    exit 15
}
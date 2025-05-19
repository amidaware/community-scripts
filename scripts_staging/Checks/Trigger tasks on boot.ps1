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
    11.05.25 SAN optimised C code and cleaned exit codes
    12.05.25 SAN fix exit codes, optimised C again, added event-log support to help with errors

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
    $host.SetShouldExit($ExitOK)
    exit $ExitOK 
} else {
    # Key doesn't exist, load and execute C# code to create the volatile registry key
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public class VolatileRegistry
{
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
    private static extern int RegCreateKeyEx(
        UIntPtr hKey,
        string lpSubKey,
        int Reserved,
        string lpClass,
        uint dwOptions,
        int samDesired,
        IntPtr lpSecurityAttributes,
        out SafeRegistryHandle phkResult,
        out int lpdwDisposition
    );

    [DllImport("advapi32.dll")]
    private static extern int RegCloseKey(SafeRegistryHandle hKey);

    public static readonly UIntPtr HKEY_LOCAL_MACHINE = (UIntPtr)0x80000002;

    [Flags]
    public enum RegistryAccess : int
    {
        KEY_QUERY_VALUE = 0x0001,
        KEY_SET_VALUE = 0x0002,
        KEY_CREATE_SUB_KEY = 0x0004,
        KEY_ENUMERATE_SUB_KEYS = 0x0008,
        KEY_NOTIFY = 0x0010,
        KEY_CREATE_LINK = 0x0020,
        KEY_WOW64_64KEY = 0x0100,
        KEY_ALL_ACCESS = 0xF003F
    }

    public const uint REG_OPTION_VOLATILE = 0x00000001;

    public static bool CreateVolatileKey(string subKey, out string message)
    {
        message = string.Empty;

        if (string.IsNullOrWhiteSpace(subKey))
        {
            message = "KO: Invalid subKey value.";
            return false;
        }

        SafeRegistryHandle hKey;
        int disposition;

        int result = RegCreateKeyEx(
            HKEY_LOCAL_MACHINE,
            subKey,
            0,
            null,
            REG_OPTION_VOLATILE,
            (int)(RegistryAccess.KEY_ALL_ACCESS | RegistryAccess.KEY_WOW64_64KEY),
            IntPtr.Zero,
            out hKey,
            out disposition
        );

        if (result == 0)
        {
            using (hKey)
            {
                message = string.Format("OK: Registry key created (disposition: {0}).", disposition);
                return true;
            }
        }
        else
        {
            message = string.Format("KO: Failed to create registry key. Error code: {0}", result);
            return false;
        }
    }
}
"@
    $EventLogName = "Application"
    $EventSource = "VolatileRegistryScript"

    if (-not [System.Diagnostics.EventLog]::SourceExists($EventSource)) {
        New-EventLog -LogName $EventLogName -Source $EventSource
    }

    try {
        # Run the C# code to create the volatile registry key
        $created = [VolatileRegistry]::CreateVolatileKey($subKey, [ref]$msg)

        Write-Output $msg

        if ($created -and ($msg -match 'OK')) {
            Write-EventLog -LogName $EventLogName -Source $EventSource -EventId $ExitCreated -EntryType Information -Message $msg

            # First run since boot, and the message says OK — trigger automation
            $host.SetShouldExit($ExitCreated)
            exit $ExitCreated
        } else {
            Write-EventLog -LogName $EventLogName -Source $EventSource -EventId 1002 -EntryType Error -Message "Registry creation failed: $msg"
            Write-Error "Failed to create the key"
            $host.SetShouldExit($ExitError)
            exit $ExitError
        }
    } catch {
        $errorMsg = "An unexpected error occurred: $_"

        Write-EventLog -LogName $EventLogName -Source $EventSource -EventId 1003 -EntryType Error -Message $errorMsg

        Write-Error $errorMsg
        $host.SetShouldExit($ExitError)
        exit $ExitError
    }

}
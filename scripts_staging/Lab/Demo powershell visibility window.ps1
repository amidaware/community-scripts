<#
.SYNOPSIS
    Demo script to controls the visibility state of the PowerShell console window.

.DESCRIPTION
    This script defines and uses a Win32 class to access native Windows API functions 
    for showing, hiding, or minimizing the PowerShell console window. It uses 
    GetConsoleWindow and ShowWindow from kernel32.dll and user32.dll, respectively.

.NOTES
    Author: SAN
    Date:02.05.25
    #public

.EXAMPLE
    # Minimize the PowerShell console window
    [Win32]::ShowWindow($consoleHandle, $SW_MINIMIZE)

    # Hide the PowerShell console window
    [Win32]::ShowWindow($consoleHandle, $SW_HIDE)

    # Restore the PowerShell console window
    [Win32]::ShowWindow($consoleHandle, $SW_RESTORE)

#>

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
}
"@ -PassThru

# Constants for ShowWindow API
$SW_HIDE = 0
$SW_SHOWNORMAL = 1
$SW_MINIMIZE = 6
$SW_SHOWMINNOACTIVE = 7
$SW_RESTORE = 9

# Get handle to the current PowerShell console window
$consoleHandle = [Win32]::GetConsoleWindow()

# Modify the window state here:
[Win32]::ShowWindow($consoleHandle, $SW_MINIMIZE)
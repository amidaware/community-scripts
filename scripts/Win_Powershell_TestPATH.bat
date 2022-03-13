@echo off

REM The last line gets the registry value of the PATH environmental variable.
REM https://docs.microsoft.com/en-us/windows/win32/sysinfo/registry-value-types
REM   ExpandString (REG_EXPAND_SZ) means %SystemRoot% will expand to C:\Windows.
REM   String (REG_SZ) means %SystemRoot% will not be expanded.

cd %TEMP%
> "%TEMP%\get-info.ps1" (
    @echo.$ENV:PATH
    @echo.$PSVersionTable
    @echo.$Host.version
    @echo.Get-Command powershell.exe
    @echo.(Get-Item -Path 'Registry^:^:HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment'^).GetValueKind('PATH'^)
)


C:\Windows\System32\WindowsPowershell\v1.0\powershell.exe -NonInteractive -ExecutionPolicy Bypass "%TEMP%\get-info.ps1"
del "%TEMP%\get-info.ps1"

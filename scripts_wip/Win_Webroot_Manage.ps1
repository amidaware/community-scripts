<#
.SYNOPSIS
    Installs or silently removes Webroot SecureAnywhere / OpenText Core Endpoint Protection.

.DESCRIPTION
    Designed to run unattended from an RMM as SYSTEM. Never prompts.

    -Install:
        Downloads the installer over HTTPS, verifies it is signed by Webroot, and runs
        it silently with the keycode (and optional group). Skips if Webroot is already
        installed.

    -Uninstall:
        Previous attempts:
            Every Safe Mode attempt is recorded in HKLM:\SOFTWARE\WebrootSafeModeRemoval.
            Each run reports the previous attempt, works out what happened to attempts
            that never reported back, cleans up leftovers, and verifies whether Webroot
            is gone. A failed Safe Mode attempt is not retried more than
            -MaxSafeModeAttempts times unless -Force is used.

        Stage 1 - normal uninstall (no reboot):
            Runs Webroot's own "WRSA.exe -uninstall". This works when the Webroot
            console policy allows uninstalls.

        Stage 2 - Safe Mode fallback (only with -SafeModeFallback or -SafeModeOnly):
            Registers a one-shot service that, in Safe Mode with Networking, stops and
            deletes Webroot's services and removes its registry keys and folders.

            Safe Mode is entered through a COPY of the default boot entry, selected
            with "bcdedit /bootsequence". That is a one-time selection: the boot after
            it is always normal mode, whether the removal succeeded, failed, hung or
            never ran. The service checks whether Webroot is gone, records the result,
            and reboots.

            Guards for the removal service failing:
              - Self-test: the service is started once in normal mode and must report
                back within 30 seconds, or staging is rolled back and the machine is
                never sent to Safe Mode.
              - Internal watchdog: the service forces the reboot after 45 minutes.
              - Independent watchdog: a second Safe Mode service built only from
                Windows components reboots the machine after 60 minutes if it is still
                in Safe Mode, even if the removal service never started.
              - Any reboot returns to normal mode.

    WARNING: Stage 2 reboots the machine twice. The RMM agent is offline while it is
    in Safe Mode. BitLocker, if on, is suspended for 2 reboots during Stage 2.

.PARAMETER Install
    Install Webroot.

.PARAMETER Key
    Webroot keycode. Defaults to the WEBROOT_KEY environment variable.

.PARAMETER Group
    Optional Webroot group code.

.PARAMETER Uninstall
    Remove Webroot.

.PARAMETER SafeModeFallback
    If the normal uninstall leaves Webroot behind, stage the Safe Mode removal.

.PARAMETER SafeModeOnly
    Skip the normal uninstall and go straight to the Safe Mode removal.

.PARAMETER NoReboot
    Stage the Safe Mode removal but don't reboot. It runs on the next reboot.

.PARAMETER RebootDelay
    Seconds before the reboot into Safe Mode, so the RMM receives this script's output.
    Default 60.

.PARAMETER MaxSafeModeAttempts
    Safe Mode attempts allowed before the script stops retrying. Default 1.

.PARAMETER Force
    Retry the Safe Mode removal even if -MaxSafeModeAttempts has been reached.

.EXAMPLE
    -Install
        (with RMM environment variable WEBROOT_KEY={{client.webroot_key}})

.EXAMPLE
    -Install -Key 1234-1234-1234-1234 -Group 0123456789

.EXAMPLE
    -Uninstall -SafeModeFallback

.EXAMPLE
    -Uninstall -SafeModeOnly -NoReboot

.NOTES
    Exit codes: 0 = installed / removed / nothing to do / Safe Mode removal staged or pending.
                1 = failure, or retry limit reached (details in output).
    After a Safe Mode run, re-run with -Uninstall to report the result.
    The Safe Mode log is kept in C:\ProgramData\WebrootRemoval_<id>\WebrootRemoval.log.
    Version: 2.0
    Author: redanthrax
    Creation Date: 2022-04-19
    Updated: 2026-11-10 - one-time Safe Mode boot, watchdogs, attempt tracking, HTTPS
                          and signature check, reliable installer exit code.
#>

param(
    [switch]$Install,
    [string]$Key = $env:WEBROOT_KEY,
    [string]$Group,
    [switch]$Uninstall,
    [switch]$SafeModeFallback,
    [switch]$SafeModeOnly,
    [switch]$NoReboot,
    [ValidateRange(0, 3600)]
    [int]$RebootDelay = 60,
    [ValidateRange(1, 10)]
    [int]$MaxSafeModeAttempts = 1,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$InstallerUrl = 'https://anywhere.webrootcloudav.com/zerol/wsasme.exe'
$InstallerSignerPattern = 'O=Webroot Inc\.|O="?Open Text'
$ServiceName = 'WebrootSafeModeRemoval'
$StateKey = 'HKLM:\SOFTWARE\WebrootSafeModeRemoval'
$SafeBootKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\$ServiceName"
$WatchdogName = 'WebrootSafeModeWatchdog'
$WatchdogSafeBootKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\$WatchdogName"
$WatchdogMinutes = 60
$WebrootServices = @('WRSVC', 'WRCoreService', 'WRSkyClient', 'WRkrn', 'WRBoot')

# ------------------------------------------------------------------ helpers

# Everything that counts as "Webroot still installed".
function Get-WebrootRemaining {
    $found = @()
    foreach ($path in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST',
                      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST') {
        if (Test-Path $path) { $found += 'Webroot uninstall entry'; break }
    }
    foreach ($svc in $WebrootServices) {
        if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc") { $found += "$svc service" }
    }
    foreach ($dir in "$env:ProgramFiles\Webroot", "${env:ProgramFiles(x86)}\Webroot") {
        if (Test-Path -LiteralPath (Join-Path $dir 'WRSA.exe')) { $found += "$dir\WRSA.exe"; break }
    }
    , $found
}

function Get-WrsaPath {
    foreach ($path in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST',
                      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST') {
        $entry = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        if ($entry.UninstallString -match '"?([^"]*WRSA\.exe)"?') {
            if (Test-Path -LiteralPath $Matches[1]) { return $Matches[1] }
        }
    }
    foreach ($dir in "$env:ProgramFiles\Webroot", "${env:ProgramFiles(x86)}\Webroot") {
        $exe = Join-Path $dir 'WRSA.exe'
        if (Test-Path -LiteralPath $exe) { return $exe }
    }
    $null
}

function Get-RemovalState {
    if (Test-Path $StateKey) { Get-ItemProperty -Path $StateKey }
}

function Set-RemovalState {
    param([hashtable]$Values)
    if (-not (Test-Path $StateKey)) { New-Item -Path $StateKey -Force | Out-Null }
    foreach ($name in $Values.Keys) {
        $value = $Values[$name]
        if ($value -is [int]) {
            New-ItemProperty -Path $StateKey -Name $name -Value $value -PropertyType DWord -Force | Out-Null
        }
        else {
            New-ItemProperty -Path $StateKey -Name $name -Value ([string]$value) -PropertyType String -Force | Out-Null
        }
    }
}

function ConvertTo-Date {
    param([string]$Value)
    if (-not $Value) { return $null }
    try { [datetime]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind) }
    catch { $null }
}

function Write-PreviousAttempt {
    param($State)
    Write-Output "Previous Safe Mode removal attempts: $([int]$State.Attempts)"
    $fields = [ordered]@{
        'Last result'       = $State.Status
        'Detail'            = $State.Detail
        'Staged'            = $State.StagedTime
        'Safe Mode started' = $State.SafeModeStartTime
        'Finished'          = $State.FinishedTime
        'Cleanup exit code' = $State.CleanupExitCode
        'Watchdog fired'    = $State.WatchdogFired
    }
    foreach ($label in $fields.Keys) {
        if ($fields[$label]) { Write-Output ("  {0,-18}: {1}" -f $label, $fields[$label]) }
    }
    if ($State.WorkDir) {
        $log = Join-Path $State.WorkDir 'WebrootRemoval.log'
        if (Test-Path -LiteralPath $log) { Write-Output ("  {0,-18}: {1}" -f 'Log', $log) }
    }
}

function Invoke-Bcd {
    # 'Continue' so stderr from a native command doesn't throw in Windows PowerShell 5.1.
    $ErrorActionPreference = 'Continue'
    $out = & bcdedit.exe @args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "bcdedit $($args -join ' ') failed: $($out.Trim())" }
    $out
}

# Removes the services, Safe Mode registrations, boot entry and staged files.
# Keeps the log so the attempt can still be reported.
function Clear-SafeModeLeftovers {
    param([string]$BootEntry, [string]$WorkDir)
    $ErrorActionPreference = 'Continue'
    if ($BootEntry) {
        # /delete also removes the entry from bootsequence/displayorder.
        & bcdedit.exe /delete $BootEntry 2>&1 | Out-Null
    }
    foreach ($key in $SafeBootKey, $WatchdogSafeBootKey) {
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($name in $ServiceName, $WatchdogName) {
        if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
            & sc.exe delete $name | Out-Null
        }
    }
    if ($WorkDir -and (Test-Path -LiteralPath $WorkDir)) {
        Get-ChildItem -LiteralPath $WorkDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'WebrootRemoval.log' } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function New-LockedDirectory {
    # Created with an ACL of SYSTEM + Administrators only in one call, so a standard
    # user can't plant or swap files that will later run as SYSTEM.
    param([string]$Path)
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in 'S-1-5-18', 'S-1-5-32-544') {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            (New-Object System.Security.Principal.SecurityIdentifier $sid),
            'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    [System.IO.Directory]::CreateDirectory($Path, $acl) | Out-Null
}

# Runs in Safe Mode, launched by the removal service.
$cleanupScript = @'
$ErrorActionPreference = 'Continue'
$RegKeys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WOW6432Node\WRData",
    "HKLM:\SOFTWARE\WOW6432Node\WRCore",
    "HKLM:\SOFTWARE\WOW6432Node\WRMIDData",
    "HKLM:\SOFTWARE\WOW6432Node\webroot",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WRUNINST",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST",
    "HKLM:\SOFTWARE\WRData",
    "HKLM:\SOFTWARE\WRMIDData",
    "HKLM:\SOFTWARE\WRCore",
    "HKLM:\SOFTWARE\webroot"
)
$Services = @("WRSVC", "WRCoreService", "WRSkyClient", "WRkrn", "WRBoot", "wrUrlFlt")
$RegStartupPaths = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$Folders = @(
    "$env:ProgramData\WRData",
    "$env:ProgramData\WRCore",
    "$env:ProgramFiles\Webroot",
    "${env:ProgramFiles(x86)}\Webroot",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Webroot SecureAnywhere"
)

Stop-Process -Name "WRSA" -Force -ErrorAction SilentlyContinue
foreach ($Service in $Services) {
    Stop-Service -Name $Service -Force -ErrorAction SilentlyContinue
    # Remove-Service is PowerShell 6+; this runs under Windows PowerShell 5.1
    & sc.exe delete $Service 2>&1 | Out-Null
    foreach ($ControlSet in "CurrentControlSet", "ControlSet001", "ControlSet002") {
        Remove-Item -Path "HKLM:\SYSTEM\$ControlSet\Services\$Service" -Force -Recurse -ErrorAction SilentlyContinue
    }
}
foreach ($RegKey in $RegKeys) {
    Remove-Item -Path $RegKey -Force -Recurse -ErrorAction SilentlyContinue
}
foreach ($RegStartupPath in $RegStartupPaths) {
    Remove-ItemProperty -Path $RegStartupPath -Name "WRSVC" -ErrorAction SilentlyContinue
}
foreach ($Folder in $Folders) {
    Remove-Item -LiteralPath $Folder -Force -Recurse -ErrorAction SilentlyContinue
}
exit 0
'@

# Runs in Safe Mode as a service. Placeholders are filled in at staging time.
$serviceCode = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.ServiceProcess;
using System.Threading;
using Microsoft.Win32;

public class WebrootRemovalService : ServiceBase {
    const string SvcName = "__SERVICE__";
    const string StateKey = @"__STATEKEY__";
    const string WorkDir = @"__WORKDIR__";
    const string LogPath = @"__WORKDIR__\WebrootRemoval.log";
    const string CleanupPath = @"__WORKDIR__\cleanup.ps1";
    const string SafeBootKey = @"SYSTEM\CurrentControlSet\Control\SafeBoot\Network\__SERVICE__";
    const string WatchdogName = "__WATCHDOG__";
    const string WatchdogSafeBootKey = @"SYSTEM\CurrentControlSet\Control\SafeBoot\Network\__WATCHDOG__";
    const int CleanupTimeoutMs = 30 * 60 * 1000;
    const int WatchdogMs = 45 * 60 * 1000;
    const int MOVEFILE_DELAY_UNTIL_REBOOT = 0x4;
    static readonly string[] WebrootServices = { "WRSVC", "WRCoreService", "WRSkyClient", "WRkrn", "WRBoot" };
    static readonly object LogLock = new object();
    // Set once by whichever of DoWork / Watchdog finishes first.
    static int finished = 0;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);

    public WebrootRemovalService() {
        ServiceName = SvcName;
        CanStop = true;
        CanPauseAndContinue = false;
    }

    static string Now() { return DateTime.Now.ToString("o"); }

    static void Log(string message) {
        lock (LogLock) {
            try { File.AppendAllText(LogPath, DateTime.Now.ToString("s") + " " + message + Environment.NewLine); } catch { }
        }
    }

    static void SetState(string name, string value) {
        try {
            using (RegistryKey k = Registry.LocalMachine.CreateSubKey(StateKey)) {
                k.SetValue(name, value ?? "", RegistryValueKind.String);
            }
        } catch (Exception e) { Log("State write failed (" + name + "): " + e.Message); }
    }

    static string GetState(string name) {
        try {
            using (RegistryKey k = Registry.LocalMachine.OpenSubKey(StateKey)) {
                return k == null ? null : k.GetValue(name) as string;
            }
        } catch { return null; }
    }

    static void Finish(string status, string detail) {
        SetState("Status", status);
        SetState("Detail", detail);
        SetState("FinishedTime", Now());
        Log("Result: " + status + " - " + detail);
    }

    static bool InSafeMode() {
        using (RegistryKey k = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\SafeBoot\Option")) {
            return k != null && k.GetValue("OptionValue") != null;
        }
    }

    // Runs a process with no usable stdin (so a prompt fails instead of hanging),
    // logs its output, and returns its exit code or -1 on timeout/failure.
    static int Run(string fileName, string arguments, int timeoutMs) {
        try {
            using (Process p = new Process()) {
                p.StartInfo.FileName = fileName;
                p.StartInfo.Arguments = arguments;
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.CreateNoWindow = true;
                p.StartInfo.RedirectStandardInput = true;
                p.StartInfo.RedirectStandardOutput = true;
                p.StartInfo.RedirectStandardError = true;
                p.OutputDataReceived += (s, e) => { if (e.Data != null) Log("  " + e.Data); };
                p.ErrorDataReceived += (s, e) => { if (e.Data != null) Log("  " + e.Data); };
                p.Start();
                p.StandardInput.Close();
                p.BeginOutputReadLine();
                p.BeginErrorReadLine();
                if (!p.WaitForExit(timeoutMs)) {
                    try { p.Kill(); } catch { }
                    Log(fileName + " timed out after " + (timeoutMs / 1000) + "s");
                    return -1;
                }
                p.WaitForExit();
                return p.ExitCode;
            }
        } catch (Exception e) {
            Log(fileName + " failed to run: " + e.Message);
            return -1;
        }
    }

    // Same checks as the PowerShell side: uninstall entry, services, WRSA.exe.
    static string FindRemaining() {
        List<string> found = new List<string>();
        foreach (RegistryView view in new RegistryView[] { RegistryView.Registry64, RegistryView.Registry32 }) {
            try {
                using (RegistryKey hklm = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
                using (RegistryKey k = hklm.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WRUNINST")) {
                    if (k != null && !found.Contains("Webroot uninstall entry")) found.Add("Webroot uninstall entry");
                }
            } catch (Exception e) { Log("Registry check failed: " + e.Message); }
        }
        foreach (string svc in WebrootServices) {
            using (RegistryKey k = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\" + svc)) {
                if (k != null) found.Add(svc + " service");
            }
        }
        foreach (string dir in new string[] {
                Environment.GetEnvironmentVariable("ProgramFiles"),
                Environment.GetEnvironmentVariable("ProgramFiles(x86)") }) {
            if (!string.IsNullOrEmpty(dir) && File.Exists(Path.Combine(dir, @"Webroot\WRSA.exe"))) {
                found.Add(Path.Combine(dir, @"Webroot\WRSA.exe"));
                break;
            }
        }
        return string.Join("; ", found.ToArray());
    }

    protected override void OnStart(string[] args) {
        // Pre-flight from the staging script: "sc start <svc> selftest <token>".
        // Proves the service starts and can write state; does nothing else.
        if (args != null && args.Length >= 2 && args[0] == "selftest") {
            SetState("SelfTest", args[1]);
            Log("Self-test OK");
            new Thread(() => { Thread.Sleep(1000); Stop(); }).Start();
            return;
        }

        // Return to the SCM immediately; the work can take many minutes.
        new Thread(DoWork).Start();
        Thread watchdog = new Thread(Watchdog);
        watchdog.IsBackground = true;
        watchdog.Start();
    }

    void DoWork() {
        if (!InSafeMode()) {
            // The one-time Safe Mode boot didn't happen. Never run the cleanup in normal mode.
            Log("Service started outside Safe Mode; removal not run.");
            if (Interlocked.Exchange(ref finished, 1) == 0) {
                Finish("Failed", "Removal service did not run in Safe Mode (it first started in normal mode, so the Safe Mode boot was skipped or the service failed there); removal did not run");
                Unregister();
            }
            Stop();
            return;
        }

        SetState("Status", "Running");
        SetState("SafeModeStartTime", Now());
        Log("Safe Mode Webroot removal started");

        string powershell = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
        int code = Run(powershell, "-NoProfile -ExecutionPolicy Bypass -File \"" + CleanupPath + "\"", CleanupTimeoutMs);
        Log("cleanup.ps1 exit code: " + code);
        string remaining = FindRemaining();

        if (Interlocked.Exchange(ref finished, 1) != 0) return; // watchdog already finished up
        SetState("CleanupExitCode", code.ToString());
        if (remaining.Length == 0) {
            Finish("Succeeded", "Cleanup exit code " + code + "; no Webroot components remain");
        } else {
            Finish("Failed", "Webroot still present after Safe Mode cleanup (exit code " + code + "): " + remaining);
        }
        Unregister();
        Reboot();
    }

    static void Watchdog() {
        Thread.Sleep(WatchdogMs);
        if (Interlocked.Exchange(ref finished, 1) == 0) {
            Finish("Failed", "Watchdog: removal did not finish within " + (WatchdogMs / 60000) + " minutes");
            Unregister();
            Reboot();
        }
    }

    static void Unregister() {
        // The watchdog's already-running process is left alone: if the reboot
        // below fails, it still reboots the machine.
        foreach (string key in new string[] { SafeBootKey, WatchdogSafeBootKey }) {
            try { Registry.LocalMachine.DeleteSubKeyTree(key, false); } catch (Exception e) { Log("SafeBoot key removal failed: " + e.Message); }
        }
        Log("sc delete exit code: " + Run("sc.exe", "delete " + SvcName, 30000));
        Log("sc delete watchdog exit code: " + Run("sc.exe", "delete " + WatchdogName, 30000));
        string entry = GetState("BootEntry");
        if (!string.IsNullOrEmpty(entry)) {
            // If this fails the script removes the entry on its next run.
            Log("bcdedit delete boot entry exit code: " + Run("bcdedit.exe", "/delete " + entry, 30000));
        }
        try {
            foreach (string f in Directory.GetFiles(WorkDir)) {
                if (!string.Equals(f, LogPath, StringComparison.OrdinalIgnoreCase)) {
                    MoveFileEx(f, null, MOVEFILE_DELAY_UNTIL_REBOOT);
                }
            }
        } catch (Exception e) { Log("Scheduling file cleanup failed: " + e.Message); }
    }

    static void Reboot() {
        // Safe Mode was a one-time boot (bcdedit /bootsequence): any reboot returns to normal mode.
        for (int attempt = 1; attempt <= 3; attempt++) {
            int code = Run("shutdown.exe", "/r /f /t 5 /c \"Webroot removal finished\"", 30000);
            Log("shutdown attempt " + attempt + " exit code: " + code);
            if (code == 0) return;
            Thread.Sleep(10000);
        }
        Log("Could not trigger a reboot. Any manual reboot returns to normal mode.");
    }

    public static void Main() {
        ServiceBase.Run(new WebrootRemovalService());
    }
}
'@

# --------------------------------------------------------------- pre-checks

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Must run as SYSTEM or an administrator."
    exit 1
}

if ($Install.IsPresent -eq $Uninstall.IsPresent) {
    Write-Output "Specify exactly one of -Install or -Uninstall."
    exit 1
}

# ------------------------------------------------------------------ install

if ($Install) {
    if (-not $Key) {
        Write-Output "Webroot keycode is required (-Key or the WEBROOT_KEY environment variable)."
        exit 1
    }

    $existing = Get-WebrootRemaining
    if ($existing -contains 'Webroot uninstall entry') {
        Write-Output "Webroot is already installed. Nothing to do."
        exit 0
    }

    $installDir = Join-Path $env:ProgramData ("WebrootInstall_" + [guid]::NewGuid().ToString('N').Substring(0, 12))
    $exitCode = 1
    try {
        New-LockedDirectory -Path $installDir
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $installer = Join-Path $installDir 'wsasme.exe'
        Write-Output "Downloading installer."
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $installer -UseBasicParsing

        $sig = Get-AuthenticodeSignature -FilePath $installer
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch $InstallerSignerPattern) {
            throw "Installer signature check failed (status: $($sig.Status), signer: $($sig.SignerCertificate.Subject))."
        }

        $arguments = @("/key=$Key", '/silent')
        if ($Group) { $arguments += "/group=$Group" }

        Write-Output "Starting install."
        $process = Start-Process -FilePath $installer -ArgumentList $arguments -WindowStyle Hidden -PassThru
        # Reading Handle makes ExitCode available after the wait (PowerShell quirk).
        $null = $process.Handle
        if (-not $process.WaitForExit(300000)) {
            $process | Stop-Process -Force -ErrorAction SilentlyContinue
            throw "Install timed out after 300 seconds."
        }
        if ($process.ExitCode -ne 0) {
            throw "Installer exit code: $($process.ExitCode)."
        }

        Write-Output "Installation complete."
        $exitCode = 0
    }
    catch {
        Write-Output "Install failed: $($_.Exception.Message)"
    }
    finally {
        Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit $exitCode
}

# --------------------------------------------- uninstall: previous attempts

$state = Get-RemovalState
$attempts = 0
$previousFailed = $false

if ($state -and $state.Status) {
    $attempts = [int]$state.Attempts
    $lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $stagedTime = ConvertTo-Date $state.StagedTime

    if ($state.Status -eq 'Staged' -and $stagedTime -and $lastBoot -lt $stagedTime) {
        Write-PreviousAttempt $state
        Write-Output "A Safe Mode removal is already staged and waiting for a reboot. Not staging another."
        exit 0
    }

    # Attempts that never reported a result.
    switch ($state.Status) {
        'Preparing' { Set-RemovalState @{ Status = 'StagingFailed'; Detail = 'Staging was interrupted before it completed' } }
        'Staged' {
            if ($state.WatchdogFired) {
                $detail = "Removal service never started in Safe Mode; the watchdog rebooted the machine after $WatchdogMinutes minutes"
            }
            else {
                $detail = 'Machine rebooted but the removal service never ran in Safe Mode (rebooted manually before the watchdog fired, or the watchdog did not run either)'
            }
            Set-RemovalState @{ Status = 'Failed'; Detail = $detail }
        }
        'Running' {
            if ($state.WatchdogFired) {
                $detail = "Removal started in Safe Mode but hung; the watchdog rebooted the machine after $WatchdogMinutes minutes"
            }
            else {
                $detail = 'Removal started in Safe Mode but never finished (crash, power loss or manual reboot)'
            }
            Set-RemovalState @{ Status = 'Failed'; Detail = $detail }
        }
    }

    $state = Get-RemovalState
    Write-PreviousAttempt $state
    Clear-SafeModeLeftovers -BootEntry $state.BootEntry -WorkDir $state.WorkDir
    $previousFailed = $state.Status -in 'Failed', 'StagingFailed'
}

$remaining = Get-WebrootRemaining

if ($state -and $state.Status) {
    if ($remaining.Count -eq 0) {
        # Removal confirmed: reset the retry counter so a future reinstall can be removed again.
        Set-RemovalState @{ Verified = 'Webroot not present'; VerifiedTime = (Get-Date -Format o); Attempts = 0 }
        $attempts = 0
    }
    else {
        Set-RemovalState @{ Verified = "Webroot still present: $($remaining -join '; ')"; VerifiedTime = (Get-Date -Format o) }
        if ($state.Status -eq 'Succeeded') {
            Write-Output "Previous attempt reported success, but Webroot is still present."
            Set-RemovalState @{ Status = 'Failed'; Detail = "Reported success but Webroot still present after reboot: $($remaining -join '; ')" }
            $previousFailed = $true
        }
    }
}

if ($remaining.Count -eq 0 -and -not $SafeModeOnly) {
    Write-Output "Webroot not found."
    exit 0
}

if ($remaining.Count -gt 0) {
    Write-Output "Webroot found:"
    $remaining | ForEach-Object { Write-Output "  $_" }
}
else {
    Write-Output "No Webroot components detected; running the Safe Mode cleanup anyway (-SafeModeOnly)."
}

# ------------------------------------------- stage 1: Webroot's own uninstall

if (-not $SafeModeOnly) {
    $wrsa = Get-WrsaPath
    if ($wrsa) {
        Write-Output "Running $wrsa -uninstall"
        try {
            $proc = Start-Process -FilePath $wrsa -ArgumentList '-uninstall' -WindowStyle Hidden -PassThru
            $null = $proc.Handle
            if (-not $proc.WaitForExit(600000)) {
                $proc | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-Output "  Timed out after 10 minutes."
            }
            else {
                Write-Output "  Exit code: $($proc.ExitCode)"
            }
        }
        catch {
            Write-Output "  Error running WRSA.exe: $($_.Exception.Message)"
        }
    }
    else {
        Write-Output "WRSA.exe not found; skipping the normal uninstall."
    }

    $remaining = Get-WebrootRemaining
    if ($remaining.Count -eq 0) {
        Write-Output "Webroot removed."
        exit 0
    }
    $onlyServicesLeft = @($remaining | Where-Object { $_ -notmatch ' service$' }).Count -eq 0
    if ($onlyServicesLeft) {
        # Only service registrations left: they're removed when the machine reboots.
        Write-Output "Webroot uninstalled; a reboot is required to finish. Re-run after the reboot to confirm."
        exit 0
    }

    Write-Output "Still present after the normal uninstall:"
    $remaining | ForEach-Object { Write-Output "  $_" }

    if (-not $SafeModeFallback) {
        Write-Output "Allow uninstalls in the Webroot console policy, or re-run with -SafeModeFallback to remove in Safe Mode."
        exit 1
    }
}

# ---------------------------------------------------- stage 2: Safe Mode

if ($attempts -ge $MaxSafeModeAttempts -and -not $Force) {
    Write-Output "Safe Mode removal has already been attempted $attempts time(s) (limit $MaxSafeModeAttempts) and Webroot is still present."
    Write-Output "Not retrying. Check the log above, then re-run with -Force to try again."
    exit 1
}
if ($previousFailed) {
    Write-Output "Previous Safe Mode attempt failed (see above). Retrying: attempt $($attempts + 1) of $MaxSafeModeAttempts."
}

Write-Output "Staging Safe Mode removal."
$workDir = Join-Path $env:ProgramData ("WebrootRemoval_" + [guid]::NewGuid().ToString('N').Substring(0, 12))
$bootEntry = $null
$bitlockerSuspended = $false

Set-RemovalState @{
    Status            = 'Preparing'
    StagedTime        = (Get-Date -Format o)
    WorkDir           = $workDir
    BootEntry         = ''
    SafeModeStartTime = ''
    FinishedTime      = ''
    CleanupExitCode   = ''
    Detail            = ''
    Verified          = ''
    VerifiedTime      = ''
    WatchdogFired     = ''
    SelfTest          = ''
}

try {
    New-LockedDirectory -Path $workDir
    $cleanupScript | Out-File -FilePath (Join-Path $workDir 'cleanup.ps1') -Encoding utf8

    $serviceExe = Join-Path $workDir 'WebrootRemovalService.exe'
    $code = $serviceCode.Replace('__SERVICE__', $ServiceName).
        Replace('__WATCHDOG__', $WatchdogName).
        Replace('__STATEKEY__', ($StateKey -replace '^HKLM:\\', '')).
        Replace('__WORKDIR__', $workDir)
    Add-Type -TypeDefinition $code -Language CSharp -OutputAssembly $serviceExe -OutputType ConsoleApplication -ReferencedAssemblies 'System.ServiceProcess'

    New-Service -Name $ServiceName -BinaryPathName "`"$serviceExe`"" -DisplayName 'Webroot Safe Mode Removal' -StartupType Automatic | Out-Null
    New-Item -Path $SafeBootKey -Force | Out-Null
    Set-Item -Path $SafeBootKey -Value 'Service'

    # Pre-flight: start the service once in normal mode. If it can't start and
    # report back now, it won't in Safe Mode either, so don't go there.
    $token = [guid]::NewGuid().ToString('N')
    & sc.exe start $ServiceName selftest $token | Out-Null
    $selfTestOk = $false
    for ($i = 0; $i -lt 30 -and -not $selfTestOk; $i++) {
        Start-Sleep -Seconds 1
        $selfTestOk = ((Get-RemovalState).SelfTest -eq $token)
    }
    if (-not $selfTestOk) {
        throw "Removal service failed its self-test (did not start and report back within 30 seconds)."
    }
    for ($i = 0; $i -lt 15 -and (Get-Service -Name $ServiceName).Status -ne 'Stopped'; $i++) {
        Start-Sleep -Seconds 1
    }
    Write-Output "Removal service self-test passed."

    # Independent watchdog, made only of Windows binaries, so it works even if
    # the .NET removal service can't start in Safe Mode. cmd.exe isn't a real
    # service, so the outer cmd starts a detached child and exits; the SCM logs
    # a start failure for it after 45 seconds (expected) while the child keeps running.
    $watchdogCmd = Join-Path $workDir 'watchdog.cmd'
    $stateKeyReg = $StateKey -replace '^HKLM:', 'HKLM'
    @"
@echo off
reg query "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" /v OptionValue >nul 2>&1
if errorlevel 1 (
    rem Normal mode: nothing to guard. Remove ourselves.
    reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\$WatchdogName" /f >nul 2>&1
    sc delete $WatchdogName >nul 2>&1
    exit /b 0
)
ping -n $($WatchdogMinutes * 60 + 1) 127.0.0.1 >nul
reg add "$stateKeyReg" /v WatchdogFired /d "%date% %time%" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\$ServiceName" /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\$WatchdogName" /f >nul 2>&1
sc delete $ServiceName >nul 2>&1
sc delete $WatchdogName >nul 2>&1
shutdown /r /f /t 0
"@ | Out-File -FilePath $watchdogCmd -Encoding ascii

    New-Service -Name $WatchdogName -BinaryPathName "cmd.exe /c start `"`" /b cmd.exe /c `"$watchdogCmd`"" -DisplayName 'Webroot Safe Mode Removal Watchdog' -StartupType Automatic | Out-Null
    New-Item -Path $WatchdogSafeBootKey -Force | Out-Null
    Set-Item -Path $WatchdogSafeBootKey -Value 'Service'

    # Changing boot configuration can trigger BitLocker recovery; suspend across both reboots.
    $blv = $null
    if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        $blv = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue
    }
    if ($blv -and $blv.ProtectionStatus -eq 'On') {
        Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 2 | Out-Null
        $bitlockerSuspended = $true
        Write-Output "BitLocker suspended for 2 reboots."
    }

    # One-time Safe Mode boot: a copy of the default entry with safeboot set,
    # selected with bootsequence. {default} itself is never modified, so the
    # boot after this one is always normal mode.
    $copyOut = Invoke-Bcd /copy '{default}' /d 'Webroot Removal (Safe Mode)'
    if ($copyOut -notmatch '\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}') {
        throw "Could not read the new boot entry id from bcdedit output: $copyOut"
    }
    $bootEntry = $Matches[0]
    Set-RemovalState @{ BootEntry = $bootEntry }
    Invoke-Bcd /set $bootEntry safeboot network | Out-Null
    Invoke-Bcd /displayorder $bootEntry /remove | Out-Null
    Invoke-Bcd /bootsequence $bootEntry | Out-Null

    Set-RemovalState @{ Status = 'Staged'; Attempts = ($attempts + 1) }
}
catch {
    $reason = $_.Exception.Message
    Write-Output "Staging failed: $reason"
    Write-Output "Rolling back."
    Clear-SafeModeLeftovers -BootEntry $bootEntry -WorkDir $workDir
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($bitlockerSuspended) {
        Resume-BitLocker -MountPoint $env:SystemDrive -ErrorAction SilentlyContinue | Out-Null
    }
    Set-RemovalState @{ Status = 'StagingFailed'; Detail = "Staging failed: $reason"; FinishedTime = (Get-Date -Format o) }
    exit 1
}

Write-Output "Safe Mode removal staged (attempt $($attempts + 1) of $MaxSafeModeAttempts)."
Write-Output "Log after it runs: $workDir\WebrootRemoval.log. Re-run with -Uninstall afterwards to report the result."
if ($NoReboot) {
    Write-Output "Not rebooting (-NoReboot). The next reboot goes into Safe Mode once, then back to normal."
}
else {
    Write-Output "Rebooting into Safe Mode in $RebootDelay seconds. The machine reboots to normal mode when done."
    & shutdown.exe /r /t $RebootDelay /c "Webroot removal: rebooting into Safe Mode" | Out-Null
}
exit 0

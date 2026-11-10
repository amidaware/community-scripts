<#
.SYNOPSIS
    Silently removes ESET endpoint products (and optionally the ESET Management Agent).

.DESCRIPTION
    Designed to run unattended from an RMM as SYSTEM. Never prompts.

    Previous attempts:
        Every Safe Mode attempt is recorded in HKLM:\SOFTWARE\EsetSafeModeRemoval.
        On each run the script reports the previous attempt (result, timings, uninstaller
        exit code, log path), works out what happened to attempts that never reported
        back (service never ran, interrupted run), cleans up anything left behind, and
        verifies whether ESET is actually gone. A Safe Mode attempt is not retried more
        than -MaxSafeModeAttempts times unless -Force is used.

    Stage 1 - MSI uninstall (no reboot):
        Finds ESET products in the Uninstall registry keys and removes each one with
        msiexec /x {ProductCode} /qn, passing PASSWORD= when the product's settings are
        password protected. Endpoint products are removed first, the agent last.

    Stage 2 - Safe Mode fallback (only with -SafeModeFallback or -SafeModeOnly):
        Downloads the official ESET Uninstaller over HTTPS, verifies its ESET signature,
        and registers a one-shot service that runs "esetuninstaller.exe /force" in
        Safe Mode with Networking.

        Safe Mode is entered through a COPY of the default boot entry, selected with
        "bcdedit /bootsequence". That is a one-time selection: the boot after it is
        always normal mode, whether the removal succeeded, failed, hung or never ran.
        The service checks whether ESET is gone, records the result, and reboots.

        Guards for the removal service failing:
          - Self-test: before anything touches the boot configuration, the service is
            started once in normal mode and must report back within 30 seconds, or
            staging is rolled back and the machine is never sent to Safe Mode.
          - Internal watchdog: the service forces the reboot after 45 minutes.
          - Independent watchdog: a second Safe Mode service built only from Windows
            components (cmd.exe, reg.exe, shutdown.exe) reboots the machine after
            60 minutes if it is still in Safe Mode, even if the removal service never
            started. It does nothing in normal mode except delete itself.
          - Any reboot returns to normal mode, so a manual or remote power cycle also
            recovers the machine.

    WARNING: Stage 2 reboots the machine twice. The RMM agent is offline while it
    is in Safe Mode. ESET's uninstaller /force removes ALL ESET components it finds.
    BitLocker, if on, is suspended for 2 reboots during Stage 2.

    The script refuses to run on machines with ESET Full Disk Encryption, ESET PROTECT
    Server, ESET Bridge or similar server components installed.

.PARAMETER Password
    Uninstall password from the ESET policy (Access Setup / password protected settings).
    Prefer passing it through the ESET_PASSWORD environment variable so it doesn't show
    in script arguments. Not needed for the Safe Mode fallback.

.PARAMETER SafeModeFallback
    If the MSI uninstall leaves ESET behind, stage the Safe Mode removal.

.PARAMETER SafeModeOnly
    Skip the MSI uninstall and go straight to the Safe Mode removal.

.PARAMETER KeepAgent
    Do not uninstall the ESET Management Agent during the MSI stage.
    (Has no effect on the Safe Mode stage, which removes everything.)

.PARAMETER NoReboot
    Stage the Safe Mode removal but don't reboot. It runs on the next reboot.

.PARAMETER RebootDelay
    Seconds before the reboot into Safe Mode, so the RMM receives this script's output.
    Default 60.

.PARAMETER MaxSafeModeAttempts
    Safe Mode attempts allowed before the script stops retrying. Default 1: after a
    failed Safe Mode attempt the script reports it and stops until someone
    investigates and re-runs with -Force (or a higher limit).

.PARAMETER Force
    Retry the Safe Mode removal even if -MaxSafeModeAttempts has been reached.

.PARAMETER UninstallerUrl
    Download URL of the ESET Uninstaller tool (KB2289).

.EXAMPLE
    -SafeModeFallback
        (with RMM environment variable ESET_PASSWORD={{client.eset_uninstall_password}})

.EXAMPLE
    -Password "{{client.eset_uninstall_password}}" -KeepAgent

.EXAMPLE
    -SafeModeOnly -NoReboot

.NOTES
    Exit codes: 0 = ESET removed, nothing to remove, or Safe Mode removal staged/pending.
                1 = failure, or retry limit reached (details in output).
    After a Safe Mode run, re-run this script (no switches needed) to report the result.
    Version: 1.1
    Author: redanthrax
    Creation Date: 2026-11-10
#>

param(
    [string]$Password = $env:ESET_PASSWORD,
    [switch]$SafeModeFallback,
    [switch]$SafeModeOnly,
    [switch]$KeepAgent,
    [switch]$NoReboot,
    [ValidateRange(0, 3600)]
    [int]$RebootDelay = 60,
    [ValidateRange(1, 10)]
    [int]$MaxSafeModeAttempts = 1,
    [switch]$Force,
    [string]$UninstallerUrl = 'https://download.eset.com/com/eset/tools/installers/eset_apps_remover/latest/uninstaller.exe'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ServiceName = 'EsetSafeModeRemoval'
$StateKey = 'HKLM:\SOFTWARE\EsetSafeModeRemoval'
$SafeBootKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\$ServiceName"
$WatchdogName = 'EsetSafeModeWatchdog'
$WatchdogSafeBootKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\$WatchdogName"
$WatchdogMinutes = 60
# Components we must never remove blindly (encrypted disks, management servers).
$BlockedPattern = 'Encryption|PROTECT Server|PROTECT On-Prem|Remote Administrator Server|ESET Bridge|Rogue Detection|Web Console|Mobile Device Connector'
$AgentPattern = 'Management Agent|Remote Administrator Agent'

# ------------------------------------------------------------------ helpers

function Get-EsetProducts {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.Publisher -like 'ESET*' -and $_.DisplayName } |
        Sort-Object -Property PSChildName -Unique
}

# Everything that counts as "ESET still installed": products, plus the kernel
# service, which can survive a broken uninstall without an Uninstall entry.
function Get-EsetRemaining {
    $names = @(Get-EsetProducts | ForEach-Object { $_.DisplayName })
    if ($KeepAgent) { $names = @($names | Where-Object { $_ -notmatch $AgentPattern }) }
    if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\ekrn') { $names += 'ekrn service' }
    , $names
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
        'Last result'           = $State.Status
        'Detail'                = $State.Detail
        'Staged'                = $State.StagedTime
        'Safe Mode started'     = $State.SafeModeStartTime
        'Finished'              = $State.FinishedTime
        'Uninstaller exit code' = $State.UninstallerExitCode
        'Watchdog fired'        = $State.WatchdogFired
    }
    foreach ($label in $fields.Keys) {
        if ($fields[$label]) { Write-Output ("  {0,-22}: {1}" -f $label, $fields[$label]) }
    }
    if ($State.WorkDir) {
        $log = Join-Path $State.WorkDir 'EsetRemoval.log'
        if (Test-Path -LiteralPath $log) { Write-Output ("  {0,-22}: {1}" -f 'Log', $log) }
    }
}

function Invoke-Bcd {
    # 'Continue' so stderr from a native command doesn't throw in Windows PowerShell 5.1.
    $ErrorActionPreference = 'Continue'
    $out = & bcdedit.exe @args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "bcdedit $($args -join ' ') failed: $($out.Trim())" }
    $out
}

# Removes the service, Safe Mode registration, boot entry and staged binaries.
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
            Where-Object { $_.Name -ne 'EsetRemoval.log' } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-MsiUninstall {
    param($Product)

    Write-Output "Uninstalling $($Product.DisplayName) $($Product.DisplayVersion) $($Product.PSChildName)"

    # Try without a password first, then with it. Only password protected
    # products accept PASSWORD=: the Management Agent fails (1603 in
    # CA_PrepsSilent) when given a password it wasn't configured with.
    $tries = @($false)
    if ($Password) { $tries += $true }

    foreach ($withPassword in $tries) {
        $suffix = if ($withPassword) { 'pw' } else { 'nopw' }
        # Timestamped so a later run doesn't overwrite the log of a failed one.
        $logFile = Join-Path $env:windir "Temp\ESET_Uninstall_$($Product.PSChildName)_$(Get-Date -Format 'yyyyMMdd-HHmmss')_$suffix.log"
        # /liwe: no property dump ('p'), so the password isn't written to the log.
        $msiArgs = "/x $($Product.PSChildName) /qn /norestart REBOOT=ReallySuppress /liwe `"$logFile`""
        if ($withPassword) {
            $msiArgs += ' PASSWORD="' + $Password.Replace('"', '""') + '"'
        }

        $proc = Start-Process -FilePath "$env:windir\System32\msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -WindowStyle Hidden
        $code = $proc.ExitCode
        $script:LastMsiSucceeded = $code -in 0, 1605, 1641, 3010
        $needsPassword = ($code -eq 1603) -and (Test-Path -LiteralPath $logFile) -and
            (Select-String -LiteralPath $logFile -Pattern 'Error 5004' -Quiet)

        if ($script:LastMsiSucceeded) {
            $how = if ($withPassword) { ' (with uninstall password)' } else { '' }
            switch ($code) {
                1605    { Write-Output "  Already removed." }
                0       { Write-Output "  Removed$how." }
                default { Write-Output "  Removed$how, reboot required."; $script:RebootRequired = $true }
            }
            return
        }

        if (-not $withPassword -and $Password) {
            if ($needsPassword) { Write-Output "  Password protected; retrying with the uninstall password." }
            else { Write-Output "  Failed without a password (msiexec $code); retrying with the uninstall password." }
            continue
        }

        if ($needsPassword -and $withPassword) {
            Write-Output "  Failed: uninstall password was rejected (ESET error 5004). Log: $logFile"
        }
        elseif ($needsPassword) {
            Write-Output "  Failed: uninstall password required (ESET error 5004). Log: $logFile"
        }
        else {
            Write-Output "  Failed with msiexec code $code. Log: $logFile"
        }
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

public class EsetRemovalService : ServiceBase {
    const string SvcName = "__SERVICE__";
    const string StateKey = @"__STATEKEY__";
    const string WorkDir = @"__WORKDIR__";
    const string LogPath = @"__WORKDIR__\EsetRemoval.log";
    const string UninstallerPath = @"__WORKDIR__\esetuninstaller.exe";
    const string SafeBootKey = @"SYSTEM\CurrentControlSet\Control\SafeBoot\Network\__SERVICE__";
    const string WatchdogName = "__WATCHDOG__";
    const string WatchdogSafeBootKey = @"SYSTEM\CurrentControlSet\Control\SafeBoot\Network\__WATCHDOG__";
    const int UninstallTimeoutMs = 30 * 60 * 1000;
    const int WatchdogMs = 45 * 60 * 1000;
    const int MOVEFILE_DELAY_UNTIL_REBOOT = 0x4;
    static readonly object LogLock = new object();
    // Set once by whichever of DoWork / Watchdog finishes first.
    static int finished = 0;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);

    public EsetRemovalService() {
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

    // Same checks as the PowerShell side: ESET Uninstall entries in both
    // registry views, plus the ekrn kernel service.
    static string FindRemaining() {
        List<string> found = new List<string>();
        foreach (RegistryView view in new RegistryView[] { RegistryView.Registry64, RegistryView.Registry32 }) {
            try {
                using (RegistryKey hklm = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view))
                using (RegistryKey un = hklm.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")) {
                    if (un == null) continue;
                    foreach (string sub in un.GetSubKeyNames()) {
                        using (RegistryKey k = un.OpenSubKey(sub)) {
                            if (k == null) continue;
                            string pub = k.GetValue("Publisher") as string;
                            string name = k.GetValue("DisplayName") as string;
                            if (pub != null && name != null && pub.StartsWith("ESET", StringComparison.OrdinalIgnoreCase) && !found.Contains(name)) {
                                found.Add(name);
                            }
                        }
                    }
                }
            } catch (Exception e) { Log("Registry check failed: " + e.Message); }
        }
        using (RegistryKey svc = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Services\ekrn")) {
            if (svc != null) found.Add("ekrn service");
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
            // The one-time Safe Mode boot didn't happen. Never run /force in normal mode.
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
        Log("Safe Mode ESET removal started");

        int code = Run(UninstallerPath, "/force", UninstallTimeoutMs);
        Log("esetuninstaller exit code: " + code);
        string remaining = FindRemaining();

        if (Interlocked.Exchange(ref finished, 1) != 0) return; // watchdog already finished up
        SetState("UninstallerExitCode", code.ToString());
        if (remaining.Length == 0) {
            Finish("Succeeded", "ESET Uninstaller exit code " + code + "; no ESET components remain");
        } else {
            Finish("Failed", "ESET still present after ESET Uninstaller (exit code " + code + "): " + remaining);
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
            int code = Run("shutdown.exe", "/r /f /t 5 /c \"ESET removal finished\"", 30000);
            Log("shutdown attempt " + attempt + " exit code: " + code);
            if (code == 0) return;
            Thread.Sleep(10000);
        }
        Log("Could not trigger a reboot. Any manual reboot returns to normal mode.");
    }

    public static void Main() {
        ServiceBase.Run(new EsetRemovalService());
    }
}
'@

# --------------------------------------------------------------- pre-checks

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Must run as SYSTEM or an administrator."
    exit 1
}

# ------------------------------------------------ assess previous attempts

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

$products = @(Get-EsetProducts)
$remaining = Get-EsetRemaining

if ($state -and $state.Status) {
    if ($remaining.Count -eq 0) {
        # Removal confirmed: reset the retry counter so a future reinstall can be removed again.
        Set-RemovalState @{ Verified = 'ESET not present'; VerifiedTime = (Get-Date -Format o); Attempts = 0 }
        $attempts = 0
    }
    else {
        Set-RemovalState @{ Verified = "ESET still present: $($remaining -join '; ')"; VerifiedTime = (Get-Date -Format o) }
        if ($state.Status -eq 'Succeeded') {
            Write-Output "Previous attempt reported success, but ESET is still present."
            Set-RemovalState @{ Status = 'Failed'; Detail = "Reported success but ESET still present after reboot: $($remaining -join '; ')" }
            $previousFailed = $true
        }
    }
}

$blocked = @($products | Where-Object { $_.DisplayName -match $BlockedPattern })
if ($blocked.Count -gt 0) {
    Write-Output "Refusing to run: protected ESET components are installed:"
    $blocked | ForEach-Object { Write-Output "  $($_.DisplayName) $($_.DisplayVersion)" }
    Write-Output "Remove or decrypt these manually first."
    exit 1
}

if ($remaining.Count -eq 0 -and -not $SafeModeOnly) {
    Write-Output "No ESET products found."
    exit 0
}

Write-Output "ESET found:"
$remaining | ForEach-Object { Write-Output "  $_" }

# ---------------------------------------------------------- stage 1: MSI

$script:RebootRequired = $false

if (-not $SafeModeOnly) {
    if ($products.Count -gt 0) {
        if (-not $Password) {
            Write-Output "No uninstall password supplied; password protected installs will fail with 1603."
        }

        $agents = @($products | Where-Object { $_.DisplayName -match $AgentPattern })
        $endpoint = @($products | Where-Object { $_.DisplayName -notmatch $AgentPattern })
        if ($KeepAgent) { $agents = @() }

        # Endpoint first. The agent is only removed if every endpoint product
        # came off, so a failed removal still leaves the machine reporting to
        # ESET PROTECT.
        $endpointFailed = $false
        foreach ($product in $endpoint) {
            $script:LastMsiSucceeded = $false
            try {
                Invoke-MsiUninstall -Product $product
            }
            catch {
                Write-Output "  Error starting msiexec: $($_.Exception.Message)"
            }
            if (-not $script:LastMsiSucceeded) { $endpointFailed = $true }
        }

        if ($agents.Count -gt 0 -and $endpointFailed -and -not $SafeModeFallback) {
            Write-Output "Keeping the ESET Management Agent because endpoint removal failed, so the machine stays managed."
        }
        elseif ($agents.Count -gt 0 -and $endpointFailed) {
            Write-Output "Keeping the ESET Management Agent for now; the Safe Mode removal will remove it."
        }
        else {
            foreach ($product in $agents) {
                try {
                    Invoke-MsiUninstall -Product $product
                }
                catch {
                    Write-Output "  Error starting msiexec: $($_.Exception.Message)"
                }
            }
        }
    }

    $remaining = Get-EsetRemaining
    if ($remaining.Count -eq 0) {
        if ($script:RebootRequired) { Write-Output "ESET removed. A reboot is required to finish." }
        else { Write-Output "ESET removed." }
        exit 0
    }

    Write-Output "Still present after MSI uninstall:"
    $remaining | ForEach-Object { Write-Output "  $_" }

    if (-not $SafeModeFallback) {
        Write-Output "Re-run with the correct -Password, or with -SafeModeFallback to remove in Safe Mode."
        exit 1
    }
}

# ---------------------------------------------------- stage 2: Safe Mode

if ($attempts -ge $MaxSafeModeAttempts -and -not $Force) {
    Write-Output "Safe Mode removal has already been attempted $attempts time(s) (limit $MaxSafeModeAttempts) and ESET is still present."
    Write-Output "Not retrying. Check the log above, then re-run with -Force to try again."
    exit 1
}
if ($previousFailed) {
    Write-Output "Previous Safe Mode attempt failed (see above). Retrying: attempt $($attempts + 1) of $MaxSafeModeAttempts."
}

Write-Output "Staging Safe Mode removal."
$workDir = Join-Path $env:ProgramData ("EsetRemoval_" + [guid]::NewGuid().ToString('N').Substring(0, 12))
$bootEntry = $null
$bitlockerSuspended = $false

Set-RemovalState @{
    Status              = 'Preparing'
    StagedTime          = (Get-Date -Format o)
    WorkDir             = $workDir
    BootEntry           = ''
    SafeModeStartTime   = ''
    FinishedTime        = ''
    UninstallerExitCode = ''
    Detail              = ''
    Verified            = ''
    VerifiedTime        = ''
    WatchdogFired       = ''
    SelfTest            = ''
}

try {
    New-LockedDirectory -Path $workDir

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $uninstaller = Join-Path $workDir 'esetuninstaller.exe'
    Write-Output "Downloading ESET Uninstaller."
    Invoke-WebRequest -Uri $UninstallerUrl -OutFile $uninstaller -UseBasicParsing

    $sig = Get-AuthenticodeSignature -FilePath $uninstaller
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'ESET, spol') {
        throw "ESET Uninstaller signature check failed (status: $($sig.Status), signer: $($sig.SignerCertificate.Subject))."
    }

    $serviceExe = Join-Path $workDir 'EsetRemovalService.exe'
    $code = $serviceCode.Replace('__SERVICE__', $ServiceName).
        Replace('__WATCHDOG__', $WatchdogName).
        Replace('__STATEKEY__', ($StateKey -replace '^HKLM:\\', '')).
        Replace('__WORKDIR__', $workDir)
    Add-Type -TypeDefinition $code -Language CSharp -OutputAssembly $serviceExe -OutputType ConsoleApplication -ReferencedAssemblies 'System.ServiceProcess'

    New-Service -Name $ServiceName -BinaryPathName "`"$serviceExe`"" -DisplayName 'ESET Safe Mode Removal' -StartupType Automatic | Out-Null
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
    # a start failure for it (expected) while the child keeps running.
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

    New-Service -Name $WatchdogName -BinaryPathName "cmd.exe /c start `"`" /b cmd.exe /c `"$watchdogCmd`"" -DisplayName 'ESET Safe Mode Removal Watchdog' -StartupType Automatic | Out-Null
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
    $copyOut = Invoke-Bcd /copy '{default}' /d 'ESET Removal (Safe Mode)'
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
Write-Output "Log after it runs: $workDir\EsetRemoval.log. Re-run this script afterwards to report the result."
if ($NoReboot) {
    Write-Output "Not rebooting (-NoReboot). The next reboot goes into Safe Mode once, then back to normal."
}
else {
    Write-Output "Rebooting into Safe Mode in $RebootDelay seconds. The machine reboots to normal mode when done."
    & shutdown.exe /r /t $RebootDelay /c "ESET removal: rebooting into Safe Mode" | Out-Null
}
exit 0

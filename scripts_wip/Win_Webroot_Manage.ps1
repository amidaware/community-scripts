<#
.Synopsis
   Installs Webroot or Uninstalls Webroot
.DESCRIPTION
   Installs Webroot using the Exe downloaded from the Webroot site.
   Uninstalls Webroot using a Safe-Mode startup method.
   WARNING: This will reboot the computer to safe mode then reboot back to normal.
.EXAMPLE
    Win_Webroot_Manage -Install -Key 1234-1234-1234-1234
.EXAMPLE
    Win_Webroot_Manage -Uninstall
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2022-04-19
#>

Param(
    [Parameter()]
    [string]$Key,

    [Parameter()]
    [string]$Group,

    [Parameter()]
    [switch]$Install,

    [Parameter()]
    [switch]$Uninstall
)

$rebootScript = 
@'
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
"HKLM:\SOFTWARE\webroot",
"HKLM:\SYSTEM\ControlSet001\services\WRSVC",
"HKLM:\SYSTEM\ControlSet001\services\WRkrn",
"HKLM:\SYSTEM\ControlSet001\services\WRBoot",
"HKLM:\SYSTEM\ControlSet001\services\WRCore",
"HKLM:\SYSTEM\ControlSet001\services\WRCoreService",
"HKLM:\SYSTEM\ControlSet001\services\wrUrlFlt",
"HKLM:\SYSTEM\ControlSet002\services\WRSVC",
"HKLM:\SYSTEM\ControlSet002\services\WRkrn",
"HKLM:\SYSTEM\ControlSet002\services\WRBoot",
"HKLM:\SYSTEM\ControlSet002\services\WRCore",
"HKLM:\SYSTEM\ControlSet002\services\WRCoreService",
"HKLM:\SYSTEM\ControlSet002\services\wrUrlFlt",
"HKLM:\SYSTEM\CurrentControlSet\services\WRSVC",
"HKLM:\SYSTEM\CurrentControlSet\services\WRkrn",
"HKLM:\SYSTEM\CurrentControlSet\services\WRBoot",
"HKLM:\SYSTEM\CurrentControlSet\services\WRCore",
"HKLM:\SYSTEM\CurrentControlSet\services\WRCoreService",
"HKLM:\SYSTEM\CurrentControlSet\services\wrUrlFlt"
)
$RegStartupPaths = @(
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$Folders = @(
"%ProgramData%\WRData",
"%ProgramData%\WRCore",
"%ProgramFiles%\Webroot",
"%ProgramFiles(x86)%\Webroot",
"%ProgramData%\Microsoft\Windows\Start Menu\Programs\Webroot SecureAnywhere"
)
Stop-Service -Name "WRCoreService" -Force
Stop-Service -Name "WRSkyClient" -Force
Stop-Service -Name "WRSVC" -Force
Remove-Service -Name "WRCoreService"
Remove-Service -Name "WRSkyClient"
Remove-Service -Name "WRSVC"
Stop-Process -Name "WRSA" -Force
foreach ($RegKey in $RegKeys) {
    Remove-Item -Path $RegKey -Force -Recurse -ErrorAction SilentlyContinue
}
foreach ($RegStartupPath in $RegStartupPaths) {
    Remove-ItemProperty -Path $RegStartupPath -Name "WRSVC"
}
foreach ($Folder in $Folders) {
    Remove-Item -Path "$Folder" -Force -Recurse -ErrorAction SilentlyContinue
}
'@

$serviceCode = 
@"
using System;
using System.IO;
using System.ServiceProcess;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.ComponentModel;

public enum ServiceType : int {
    SERVICE_WIN32_OWN_PROCESS = 0x00000010,
    SERVICE_WIN32_SHARE_PROCESS = 0x00000020,
};

public enum ServiceState : int {
    SERVICE_STOPPED = 0x00000001,
    SERVICE_START_PENDING = 0x00000002,
    SERVICE_STOP_PENDING = 0x00000003,
    SERVICE_RUNNING = 0x00000004,
    SERVICE_CONTINUE_PENDING = 0x00000005,
    SERVICE_PAUSE_PENDING = 0x00000006,
    SERVICE_PAUSED = 0x00000007,
};  

[StructLayout(LayoutKind.Sequential)]
public struct ServiceStatus {
    public ServiceType dwServiceType;
    public ServiceState dwCurrentState;
    public int dwControlsAccepted;
    public int dwWin32ExitCode;
    public int dwServiceSpecificExitCode;
    public int dwCheckPoint;
    public int dwWaitHint;
};

public enum Win32Error : int {
    NO_ERROR = 0,
    ERROR_APP_INIT_FAILURE = 575,
    ERROR_FATAL_APP_EXIT = 713,
    ERROR_SERVICE_NOT_ACTIVE = 1062,
    ERROR_EXCEPTION_IN_SERVICE = 1064,
    ERROR_SERVICE_SPECIFIC_ERROR = 1066,
    ERROR_PROCESS_ABORTED = 1067,
};

public class Service_WebrootUninstall : ServiceBase {
    private ServiceStatus serviceStatus;

    public Service_WebrootUninstall() {
        ServiceName = "WebrootUninstall";
        CanStop = true;
        CanPauseAndContinue = false;
    }

    [DllImport("advapi32.dll", SetLastError=true)]
    private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);

    protected override void OnStart(string[] args) {
        serviceStatus.dwServiceType = ServiceType.SERVICE_WIN32_OWN_PROCESS;
        serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
        serviceStatus.dwWin32ExitCode = 0;
        serviceStatus.dwWaitHint = 2000;
        SetServiceStatus(ServiceHandle, ref serviceStatus);

        try {
            Process p = new Process();
            p.StartInfo.UseShellExecute = false;
            p.StartInfo.RedirectStandardOutput = true;
            p.StartInfo.FileName = "PowerShell.exe";
            p.StartInfo.Arguments = "-ExecutionPolicy Bypass -c & 'C:\\Scripts\\reboot.ps1'";
            p.Start();
            string output = p.StandardOutput.ReadToEnd();
            p.WaitForExit();
            if (p.ExitCode != 0) throw new Win32Exception((int)(Win32Error.ERROR_APP_INIT_FAILURE));
            serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
            Process.Start("cmd.exe", "/C ping 1.1.1.1 -n 1 -w 3000 > Nul & Del C:\\Scripts\\reboot.exe");
            Process.Start("cmd.exe", "/c sc.exe delete WebrootUninstall");
            if(File.Exists(@"C:\Scripts\reboot.ps1")) {
                File.Delete(@"C:\Scripts\reboot.ps1");
            }
            Process.Start("cmd.exe", "/c bcdedit /deletevalue {default} safeboot");
            Process.Start("cmd.exe", "/c shutdown /r /t 0");
          } catch (Exception e) {
            serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
            Win32Exception w32ex = e as Win32Exception;
            if (w32ex == null) {
                w32ex = e.InnerException as Win32Exception;
            }    
            if (w32ex != null) {
                serviceStatus.dwWin32ExitCode = w32ex.NativeErrorCode;
            } else {
              serviceStatus.dwWin32ExitCode = (int)(Win32Error.ERROR_APP_INIT_FAILURE);
            }
          } finally {
            serviceStatus.dwWaitHint = 0;
            SetServiceStatus(ServiceHandle, ref serviceStatus);
          }
    }

    public static void Main() {
        System.ServiceProcess.ServiceBase.Run(new Service_WebrootUninstall());
    }
}
"@

function Win_Webroot_Manage {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [string]$Key,

        [Parameter()]
        [string]$Group,

        [Parameter()]
        [switch]$Install,

        [Parameter()]
        [switch]$Uninstall
    )

    Begin {
        #logic for switches
        if ($Install) {
            if (-not($Key)) {
                Write-Output "Webroot Key is required."
                Exit 1
            }

            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
            if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
        }
    }

    Process {
        Try {
            if ($Install) {
                Write-Output "Downloading installer."
                $source = "http://anywhere.webrootcloudav.com/zerol/wsasme.exe"
                $destination = "C:\packages$random\wsasme.exe"
                Invoke-WebRequest -Uri $source -OutFile $destination
                $arguments = @("/key=$Key", "/silent")
                if ($Group) {
                    $arguments += @("/group=$Group")
                }
                
                Write-Output "Starting install process."
                $process = Start-Process -NoNewWindow -FilePath $destination -ArgumentList $arguments -PassThru
                $timedOut = $null
                $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
                if ($timedOut) {
                    $process | kill
                    Write-Output "Install timed out after 300 seconds."
                    Exit 1
                }
                elseif ($process.ExitCode -ne 0) {
                    $code = $process.ExitCode
                    Write-Output "Install error code: $code."
                    Exit 1
                }

                Write-Output "Installation complete."
            }

            if ($Uninstall) {
                if (-not(Test-Path "C:\Scripts")) { New-Item -ItemType Directory -Force -path "C:\Scripts" | Out-Null }
                $rebootScript | Out-File "C:\Scripts\reboot.ps1"
                Add-Type -TypeDefinition $serviceCode -Language CSharp -OutputAssembly "C:\Scripts\reboot.exe" -OutputType ConsoleApplication -ReferencedAssemblies "System.ServiceProcess"
                New-Service WebrootUninstall "C:\Scripts\reboot.exe" -DisplayName WebrootUninstall -StartupType Automatic
                New-Item -Path HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network -Name WebrootUninstall -Force
                Set-Item -Path HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\WebrootUninstall -Value "Service"
                & cmd /c "bcdedit /set {default} safeboot network"
                & cmd /c "shutdown /r /t 0"
            }

            if ($ForceUninstall) {
                Write-Output "Force uninstall"
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
            Exit 1
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_Webroot_Manage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    Key       = $Key
    Group     = $Group
    Install   = $Install
    Uninstall = $Uninstall
}
 
Win_Webroot_Manage @scriptArgs
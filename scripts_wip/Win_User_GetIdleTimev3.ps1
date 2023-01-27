Add-Type @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace PInvoke.Win32 
    {

    public static class UserInput 
        {

        [DllImport("user32.dll", SetLastError=false)]
        private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        [StructLayout(LayoutKind.Sequential)]
        private struct LASTINPUTINFO {
            public uint cbSize;
            public int dwTime;
        }

        public static DateTime LastInput {
            get {
                DateTime bootTime = DateTime.Now.AddMilliseconds(-Environment.TickCount);
                DateTime lastInput = bootTime.AddMilliseconds(LastInputTicks);
                return lastInput;
            }
        }

        public static TimeSpan IdleTime {
            get {
                return DateTime.Now.Subtract(LastInput);
            }
        }

        public static int LastInputTicks {
            get {
                LASTINPUTINFO lii = new LASTINPUTINFO();
                lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                GetLastInputInfo(ref lii);
                return lii.dwTime;
            }
        }
    }
}
'@

Function Get-IdleTime {
    $Output = @{
        'LastInput' = [PInvoke.Win32.UserInput]::LastInput;
        'IdleTime'  = [PInvoke.Win32.UserInput]::IdleTime
    }
    
    #Store lastInput and idleTime in a property to return
    New-Object -TypeName PSObject -Property $Output
}

 
$idle = Get-IdleTime
$strIdle = ""

if ($idle.IdleTime.Days -gt 0) {
    $strIdle = "$($idle.IdleTime.Days)d " 
}

if ($idle.IdleTime.Hours -gt 0) {
    $strIdle += "$($idle.IdleTime.Hours)h " 
}

if ($idle.IdleTime.Minutes -gt 0) {
    $strIdle += "$($idle.IdleTime.Minutes)m" 
}

Write-Host "Idle $($strIdle)"
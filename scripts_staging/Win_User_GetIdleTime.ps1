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
    $idleTime = [PInvoke.Win32.UserInput]::IdleTime

    $Output = @{
        'LastInput'         = [PInvoke.Win32.UserInput]::LastInput;
        'IdleTime'          = $idleTime;
        'IdleTimeSeconds'   = $idleTime.TotalSeconds;
        'FormattedIdleTime' = '{0:D2}d:{1:D2}h:{2:D2}m' -f $idleTime.Days, $idleTime.Hours, $idleTime.Minutes, $idleTime.Seconds
    }

    # Store lastInput, idleTime, idleTimeSeconds, and formattedIdleTime in a property to return
    New-Object -TypeName PSObject -Property $Output
}

$idleTimeInfo = Get-IdleTime
Write-Output "$($idleTimeInfo.IdleTimeSeconds) seconds. $($idleTimeInfo.FormattedIdleTime)"

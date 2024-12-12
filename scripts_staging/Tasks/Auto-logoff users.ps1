<#
.SYNOPSIS
    Logs off users who have been inactive for a specified duration.

.DESCRIPTION
    This script retrieves all active user sessions on the server and logs off users 
    who have been inactive for more than the specified duration (50 minutes by default). 
    It handles different session states and extracts session IDs properly for both active and disconnected sessions.

.PARAMETER maxInactivityTime
    The maximum period of inactivity in seconds before a user is logged off. Default is 3000 seconds (50 minutes).

.EXEMPLE
    -maxInactivityTime 3600

.NOTES
    Author: SAN 
    Date: 12.06.24
    #public

.TODO
    Add user warning for the users
    move var to env

#>


param (
    [int]$maxInactivityTime = 3000
)

function Get-LastInputTime {
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class IdleTime {
            [DllImport("user32.dll")]
            public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
            public struct LASTINPUTINFO {
                public uint cbSize;
                public uint dwTime;
            }
            public static uint GetIdleTime() {
                LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
                lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
                GetLastInputInfo(ref lastInputInfo);
                return (uint)Environment.TickCount - lastInputInfo.dwTime;
            }
            public static DateTime GetLastInputTime() {
                return DateTime.Now.AddMilliseconds(-(long)GetIdleTime());
            }
        }
"@
    return [IdleTime]::GetLastInputTime()
}

# Arrays to store user information
$foundUsers = @()
$keptConnectedUsers = @()
$disconnectedUsers = @()

# Get all explorer.exe processes
$explorerProcesses = Get-Process -Name explorer -ErrorAction SilentlyContinue

if ($explorerProcesses) {
    Write-Host "Explorer.exe processes found: $($explorerProcesses.Count)"

    # Get current time
    $currentTime = Get-Date

    foreach ($process in $explorerProcesses) {
        try {
            # Get the user session ID
            $sessionId = $process.SessionId

            if ($sessionId -ge 0) {
                Write-Host "Processing Session ID: $sessionId"

                # Use query user to get session information
                $queryUserOutput = query user
                Write-Host "Query User Output:`n$queryUserOutput"

                $sessionInfo = $queryUserOutput | Select-String -Pattern " $sessionId " -SimpleMatch

                if ($sessionInfo) {
                    $sessionInfoParts = $sessionInfo -split '\s+'
                    Write-Host "Session Info Parts: $sessionInfoParts"

                    # Find the username and idle time in session info parts
                    $username = $null
                    $idleTime = $null
                    for ($i = 0; $i -lt $sessionInfoParts.Length; $i++) {
                        if ($sessionInfoParts[$i] -match '^\d+$' -and $sessionInfoParts[$i] -eq $sessionId.ToString()) {
                            $username = $sessionInfoParts[$i-1]
                            $idleTime = $sessionInfoParts[$i+2]
                            break
                        }
                    }

                    if ($username -and $idleTime) {
                        # Debugging information
                        Write-Host "Username: $username, Idle Time String: $idleTime"

                        # Attempt to parse idle time to TimeSpan
                        $idleTimeSpan = $null
                        if ($idleTime -match '^\d{1,2}:\d{2}$') {
                            # Handle formats like "1:30" or "12:45"
                            $idleTimeSpan = [TimeSpan]::Parse("00:$idleTime")
                        } elseif ($idleTime -match '^\d{1,2}:\d{2}:\d{2}$') {
                            # Handle formats like "1:30:00" or "12:45:00"
                            $idleTimeSpan = [TimeSpan]::Parse($idleTime)
                        } elseif ($idleTime -match '^\d+$') {
                            # Handle single digit idle time representing minutes
                            $idleTimeSpan = New-TimeSpan -Minutes $idleTime
                        } else {
                            Write-Host "Unable to parse idle time: $idleTime"
                        }

                        if ($idleTimeSpan) {
                            Write-Host "Username: $username, Session ID: $sessionId, Idle Time: $idleTimeSpan"

                            # Add username to found users list
                            $foundUsers += $username

                            # Check if the user is idle for more than X
                            if ($idleTimeSpan.TotalSeconds -ge $maxInactivityTime) {
                                Write-Host "User $username (Session ID: $sessionId) has been idle for more than 4 hours. Logging off..."
                                $disconnectedUsers += $username

                                # Log off the user session
                                logoff $sessionId
                            } else {
                                $keptConnectedUsers += $username
                            }
                        }
                    } else {
                        Write-Host "Unable to find username or idle time in session info parts."
                    }
                } else {
                    Write-Host "No session info found for Session ID: $sessionId"
                }
            } else {
                Write-Host "Invalid session ID: $sessionId"
            }
        } catch {
            Write-Error "Failed to process session ID $($process.SessionId): $_"
        }
    }
} else {
    Write-Host "No explorer.exe processes found."
}

# Output the lists
Write-Host "Users Found: $($foundUsers -join ', ')"
Write-Host "Users Kept Connected: $($keptConnectedUsers -join ', ')"
Write-Host "Users Disconnected: $($disconnectedUsers -join ', ')"
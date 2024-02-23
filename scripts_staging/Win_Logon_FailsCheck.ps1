# Modified based off of the work of Discord user silverswordtheitguy. Thanks!

Write-Output "Starting"

# Define a function to log login and logout events as a table
function Log-LoginLogoutEvent {
    param (
        [string]$UserName,
        [string]$EventType,
        [string]$LogonType,
        [string]$WorkstationName,
        [string]$SourceNetworkAddress
    )
    $LogMessage = New-Object PSObject -Property @{
        'Timestamp' = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        'Username' = $UserName
        'EventType' = $EventType
        'LogonType' = $LogonType
        'WorkstationName' = $WorkstationName
        'SourceNetworkAddress' = $SourceNetworkAddress
    }
    Write-Output $LogMessage
}

# Calculate the start time for the last 24 hours
$StartTime = (Get-Date).AddDays(-1)

# Initialize an ArrayList for logged events
$LoggedEvents = New-Object System.Collections.ArrayList

# Retrieve failed logon events within the last 24 hours
$FailedLogonEvents = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=$StartTime} -ErrorAction SilentlyContinue

foreach ($Event in $FailedLogonEvents) {
    $EventId = $Event.Id
    $UserName = $Event.Properties[5].Value
    $LogonType = $Event.Properties[10].Value
    $WorkstationName = $Event.Properties[13].Value
    $SourceNetworkAddress = $Event.Properties[19].Value

    $EventType = "Failed Logon"

    # Check if the username is not "SYSTEM" before logging
    if ($UserName -ne "SYSTEM") {
        $null = $LoggedEvents.Add((Log-LoginLogoutEvent -UserName $UserName -EventType $EventType -LogonType $LogonType -WorkstationName $WorkstationName -SourceNetworkAddress $SourceNetworkAddress))
    }
}

# Format the output as a table with five columns
$LoggedEvents | Format-Table -Property Timestamp, Username, EventType, LogonType, SourceNetworkAddress, WorkstationName -AutoSize

Write-Output "Finished"

# Output an exit code based on whether any failed logons were found
if ($LoggedEvents.Count -gt 0) {
    exit 1
} else {
    exit 0
}

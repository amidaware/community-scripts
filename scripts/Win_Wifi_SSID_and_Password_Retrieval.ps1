<#
.NOTES
    v1.1 8/23/2024 silversword411 complete refactor to add Connection mode column
#>

# Get the list of saved SSIDs
$wifiProfiles = (netsh wlan show profiles) | Select-String "\:(.+)$" | % { $_.Matches.Groups[1].Value.Trim() }

$results = @()

foreach ($name in $wifiProfiles) {
    $profileDetails = netsh wlan show profile name="$name" key=clear
    
    # Look for the "Connection mode" setting
    $connectionModeMatch = $profileDetails | Select-String "Connection mode\W+\:(.+)$"
    $connectionMode = if ($connectionModeMatch) { $connectionModeMatch.Matches.Groups[1].Value.Trim() } else { "Not found" }

    # Look for the password
    $passwordMatch = $profileDetails | Select-String "Key Content\W+\:(.+)$"
    $password = if ($passwordMatch) { $passwordMatch.Matches.Groups[1].Value.Trim() } else { "No password" }
    
    $results += [PSCustomObject]@{
        SSID            = $name
        PASSWORD        = $password
        CONNECTION_MODE = $connectionMode
    }
}

# Output the results in a table
$results | Format-Table -AutoSize

# Dupe of Win_Wifi_SSID_and_Password_Retrieval.ps1
<#
      .SYNOPSIS
      This Will Retrieve All Wifi SSIDs and passwords on a client 
  #>

(netsh wlan show profiles) | Select-String "\:(.+)$" | % { $name = $_.Matches.Groups[1].Value.Trim(); $_ } | % { (netsh wlan show profile name="$name" key=clear) } | Select-String "Key Content\W+\:(.+)$" | % { $pass = $_.Matches.Groups[1].Value.Trim(); $_ } | % { [PSCustomObject]@{ PROFILE_NAME = $name; PASSWORD = $pass } } | Format-Table -AutoSize

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function dischat {

  [CmdletBinding()]
  param (    
  [Parameter (Position=0,Mandatory = $True)]
  [string]$msgContent
  ) 
  
  $hookUrl = 'https://discord.com/api/webhooks/yourwebhookurlhere'
  
  $Body = @{
    #This is who the message is from
    'username' = "Title"
    'content' = $msgContent
  }

  Invoke-RestMethod -Uri $hookUrl -Method 'post' -Body $Body

}

function script {
    $machinename = "Title?"
    $publicip = (Invoke-WebRequest -uri "https://api.ipify.org?format=json" -UseBasicParsing).content | ConvertFrom-Json | Select-Object -ExpandProperty ip
    $trmminstalled = Test-Path -Path "C:\Program Files\TacticalAgent" -PathType Container

        return "$machinename Pub IP: $publicip TRMM Installed: $trmminstalled"
}

dischat (script)

Write-Output "Sent to Discord"
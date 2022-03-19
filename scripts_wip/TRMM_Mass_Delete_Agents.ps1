<#
.SYNOPSIS
    Delete agents by client and site name
.REQUIREMENTS
    - You will need an API key from Tactical RMM which should be passed as parameters (DO NOT hard code in script).  Do not run this on each agent (see notes).  
.NOTES
    - This script is designed to run on a single computer.  Ideally, it should be run on the Tactical RMM server or other trusted device.
    - This script loops through each agent uninstalling the agent and deleting each from the backend.
.PARAMETERS
    - $ApiKeyTactical   - Tactical API Key
    - $ApiUrlTactical   - Tactical API Url
    - $Client           - Limit by client name
    - $Site             - Limit by site name
.VERSION
	- v1.0 Initial Release by https://github.com/bc24fl/tacticalrmm-scripts/
#>

param(
    [string] $ApiKeyTactical,
    [string] $ApiUrlTactical,
    [string] $Client,
    [string] $Site
)

if ([string]::IsNullOrEmpty($ApiKeyTactical)) {
    throw "ApiKeyTactical must be defined. Use -ApiKeyTactical <value> to pass it."
}

if ([string]::IsNullOrEmpty($ApiUrlTactical)) {
    throw "ApiUrlTactical without the https:// must be defined. Use -ApiUrlTactical <value> to pass it."
}

if ([string]::IsNullOrEmpty($Client)) {
    throw "Client must be defined. Use -Client <value> to pass it."
}

if ([string]::IsNullOrEmpty($Site)) {
    throw "Site must be defined. Use -Site <value> to pass it."
}

$headers= @{
    'X-API-KEY' = $ApiKeyTactical
}

try {
    $agentsResult = Invoke-RestMethod -Method 'Get' -Uri "https://$ApiUrlTactical/agents" -Headers $headers -ContentType "application/json"
}
catch {
    throw "Error invoking rest call on Tactical RMM with error: $($PSItem.ToString())"
}

$agentsDeleted = 0

foreach ($agents in $agentsResult) {

    $agentId        = $agents.agent_id
    $agentHostname  = $agents.hostname
    $agentStatus    = $agents.status
    $clientName     = $agents.client_name
    $siteName       = $agents.site_name

    if ($agentStatus -eq "online" -And $clientName -eq $Client -And $siteName -eq $Site){

        $agentsDeleted += 1

        Write-Host "Working with $agentHostname - agentId $agentId"

        # Uninstall agent from client
        $body = @{
            "shell"   = "powershell"
            "cmd"     = "'C:\Program Files\TacticalAgent\unins000.exe' /VERYSILENT" 
            "timeout" = 5
        }
        try {
            $agentCmdResult = Invoke-RestMethod -Method 'Post' -Uri "https://$ApiUrlTactical/agents/$agentId/cmd/" -Body ($body|ConvertTo-Json) -Headers $headers -ContentType "application/json" 
            Write-Host "Uninstalled agent $agentHostname"
        }
        catch {
            Write-Error "Error invoking cmd on agent $agentHostname with error: $($PSItem.ToString())"
        }

        # Delete from backend
        $body = @{}
        try {
            $agentDelResult = Invoke-RestMethod -Method 'Delete' -Uri "https://$ApiUrlTactical/agents/$agentId/" -Body ($body|ConvertTo-Json) -Headers $headers -ContentType "application/json"
            Write-Host "Deleted agent $agentHostname from backend"
        }
        catch {
            Write-Error "Error invoking delete on agent $agentHostname with error: $($PSItem.ToString())"
        }
    }
} 

Write-Host "Deleted $agentsDeleted agents."
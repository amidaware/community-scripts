<#
.DESCRIPTION
Moves an Windows Workstation Agent to the first Site created for the Client with a match in the Client's "Domains" Custom Field.

Assumptions made:
    - The User will be on a Windows client machine and logged in with their Microsoft 365 account, therefore their UPN will be their M365 username (UPN)
    - The lowest value ID site per Client is the one you want the Agent to be pushed to (or Clients only have 1 site)
    - - If this is not true, you'll need to update the "Determine the Site..." region with logic that returns the desired site(s)
    - There is a Client Custom Field called "Domains" and it's for all of the the domains that could be valid for the UPN

You will need:
    - A script in TRMM that runs "whoami /upn" and the ID of that script (hover over it) - E.g. "Win_TRMM_GetLoggedOnUPN.ps1"
    - - The ID will be the value supplied to the "-whoAmIScriptId" script arguement
    - - This is deliberately not done as a script snippit because it must be run as the USER (and not SYSTEM)
    - A Client Custom Field for storing domains exists, and is populated with the domains that any valid UPN may have for the given Client
    - - The name of this field can be overridden by supplying the "-clientCustomFieldName" script argument with a value

.SYNOPSIS
Moves an Agent to the first Site created for the Client with a match in the Client's "Domains" Custom Field.  (Assumes Windows & the user is logged in with their M365 account, and requires an additional script (see Description).)

.NOTES
v1.0 2026-01-12 Owen Conti 

#>

[cmdletbinding()]
Param(
    [string]#Provided by using the script arguement "-agentId {{agent.agent_id}}"
    $agentId,
    [string]#The API Key value to use.  A better approach is to pass this with an ENVIRONMENT VARIABLE in the script triggering so your API key is not logged in the Windows Event Log on all the Clients that run this.  If you provide a value here it will override any environment variable you provide.
    $apiKey,
    [int]#The ID of the "WhoAmI" script on your environment
    $whoAmIScriptId,
    [string]#The FQDN of your API end point (the URI is built later). E.g. "api.example.com"
    $apiFQDN,
    [string]#The exact name of the Client level Custom Field used for storing the valid Domains
    $clientCustomFieldName = "Domains"
)

#region script wide parameters
If($apiKey){
    $apiAuthKey = $apiKey
} else {
    $apiAuthKey = $env:apiKey
}

$headers = @{
    'Content-Type' = 'application/json'
    'X-API-KEY' = $apiAuthKey
} #These are common to all our API calls
#endRegion


#region Collect the User's UPN using the "Who Am I" script
$whoamiPayload = @{
    output = "wait"
    emails = @()
    emailMode = "default"
    custom_field = $null
    save_all_output = $false
    script = $whoAmIScriptId
    args = @()
    env_vars = @()
    run_as_user = $false
    timeout = 10
} | ConvertTo-Json

$upn = Invoke-RestMethod -Uri "https://$apiFQDN/agents/$agentId/runscript/" -Method POST -Body $whoamiPayload -Headers $headers
If($upn.Contains("ERROR:"))
{
    #The user is not logged in with an account that presents the UPN to whoami.exe
    Write-Error "An error occured when trying to collect the UPN of the user: $upn"
    Exit 1
}
#endRegion

#region Determine the Site (and therefore Client) the user belongs to
$domain = $upn.Split("@")[1].Trim() #The trim is required as trailing spaces cause problems
#Need to define a method for doing a lookup for UPN domain to Customer ID to correct Site in TRMM
$customFields = Invoke-RestMethod -Uri "https://$apiFQDN/core/customfields" -Method GET -Headers $headers
$domainFieldId = $customFields | Where-Object -FilterScript {$_.model -eq "client" -and $_.name -eq $clientCustomFieldName} | Select-Object -ExpandProperty id

$clients = Invoke-RestMethod -Uri "https://$apiFQDN/clients/" -Method GET -Headers $headers
$siteId = $clients |
 Where-Object {$_.custom_fields.field -eq $domainFieldId -and $_.custom_fields.value -match $domain} |
  Select-Object -ExpandProperty sites |
   Sort-Object -Property id |
    Select-Object -ExpandProperty id -First 1
#endRegion

#region Move the agent to the correct site
If($siteId){

    $body = @{
        site = $siteId
    } | ConvertTo-Json

    $moveResult = Invoke-RestMethod -Method PUT -Uri "https://$apiFQDN/agents/$agentId" -Headers $headers -Body $body
    If($moveResult -eq "The agent was updated successfully")
    {
        $moveResult
        Exit 0
    } else {
        Write-Error "There was a problem with the API call to move the Agent"
        $moveResult
        Exit 1
    }
    
} else {
    Write-Error "There was a problem collecting the Site ID.  The domain value is between the asterisks: ***$domain***  Check the Clients and ensure this domain value is in the correct place."
    Exit 1
}
#endRegion
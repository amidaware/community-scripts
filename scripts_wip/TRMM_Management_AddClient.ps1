<#
.SYNOPSIS
A tool to create clients, and sites, programitcally to enable "bulk" creation of clients & sites.

.DESCRIPTION
A tool to create clients, and sites, programitcally to enable "bulk" creation of clients & sites.

Creates a site called "Site" by default as the first site.

Assumes there is a client wide custom field for storing valid domains for that client.  By default the name is assumed to be "Domains" and can be overridden using the -clientCustomFieldName parameter.

.EXAMPLE
Create a CSV file with the headers "clientName" and "domains".  If there are multiple valid domains, separate them with a semicolon (;).

$csvFilePath = (Read-Host "Provide the full file path for the CSV.")
$apiKey = (Read-Host "Enter your API key")
$apiFQDN = (Read-Host "Enter the FQDN portion of your TRMM API URI - e.g. api.example.com")
Import-CSV -Path $csvFilePath | New-TrmmClient.ps1 -apiKey $apiKey -apiFQDN $apiFQDN

.NOTES
v1.0 2026-01-14 Owen Conti

#>
[cmdletbinding()]
Param(
    [Parameter(ValueFromPipelineByPropertyName)][string]
    $clientName,
    
    [Parameter(ValueFromPipelineByPropertyName)][string[]]#Uses a custom field to store the domains that M365 users will be using as part of their UPNs.  When importing by CSV, have the list of Domains separated by a semicolon (;).
    $domains,
    
    [string[]]#"Site" is created first by default.  This is a list of additional Site names to create.
    $sites,
    
    [string]#The API Key value to use
    $apiKey,
    
    [string]#The FQDN of your API end point (the URI is built later). E.g. "api.example.com"
    $apiFQDN,
    
    [string]#The exact name of the Client level Custom Field used for storing the valid Domains
    $clientCustomFieldName = "Domains"
)

BEGIN {
    $headers = @{
        'Content-Type' = 'application/json'
        'X-API-KEY' = $apiKey
    } #These are common to all our API calls

    #Get the initial list of clients
    $clients = Invoke-RestMethod -Uri "https://$apiFQDN/clients/" -Method GET -Headers $headers

    #Get CustomField ID for the given name
    $customFieldDetails = Invoke-RestMethod -Uri "https://$apiFQDN/core/customfields/" -Method GET -Headers $headers
    $customFieldDetails = $customFieldDetails | Where-Object -FilterScript {$_.model -eq "client" -and $_.name -eq $clientCustomFieldName}
}

PROCESS{

    If($domains.Contains(";")){
        $domains = $domains.Split(";")
    }

    #First check if the client already exists
    $existingClient = $clients | Where-Object -FilterScript {$_.name -eq $clientName}

    If($existingClient){
        Write-Error "$clientName already exists (ID $($existingClient.ID))."        
    } else {
        #Create the Client
        $clientPayload = (@{
            client = @{
                name = $clientName
            }
            custom_fields = @(
                @{
                    field = $customFieldDetails.id
                    string_value = $domains -join "\n"
                }
                )
            site = @{
                name = "Site"
            }
        } | ConvertTo-Json).Replace("\\n","\n")

        Invoke-RestMethod -Uri "https://$apiFQDN/clients/" -Method POST -Headers $headers -body $clientPayload

        $clients = Invoke-RestMethod -Uri "https://$apiFQDN/clients/" -Method GET -Headers $headers
            #The API doesn't return the new Client ID, so we need to collect all clients again.  Has the added advantage of preventing us from trying to create duplicates if the CSV has duplicated rows.
        $newClientDetails = $clients | Where-Object -FilterScript {$_.name -eq $clientName}

        #Add the Sites
        If($sites){
            $existingSites = Invoke-RestMethod -Uri "https://$apiFQDN/clients/sites/" -Method GET -Headers $headers
            Foreach($site in $sites){
                If($existingSites | Where-Object -FilterScript {$_.client -eq $newClientDetails.id -and $_.name -eq $site}){
                    "Site already exists"
                    Continue
                }
                $sitePayload = @{
                    site = @{
                        client = $newClientDetails.id
                        name = $site
                    }
                } | ConvertTo-Json
                Invoke-RestMethod -Uri "https://$apiFQDN/clients/sites/" -Method POST -Headers $headers -body $sitePayload
            }
        }
    }
}
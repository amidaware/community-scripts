# https://github.com/RKBlack/PoshTRMM/blob/main/Public/Get-SoftwareFromTRMM.ps1

function Get-SoftwareFromTRMM {
    param (
        [Parameter(Mandatory)]
        [string]
        $TRMMApiKey,
        [Parameter(Mandatory)]
        [string]
        $TRMMApiUrl,
        [string]
        #Comma Seperated List
        $ClientFilter
    )

    $headers = @{
        'X-API-KEY' = $TRMMApiKey
    }

    $url = $TRMMApiUrl
    $agentsResult = (Invoke-RestMethod -Method 'Get' -Uri "$url/agents/" -Headers $headers -ContentType 'application/json') | Where-Object {
        if ($clientFilter) {
            $_.client_name -in $clientFilter
        }
        else {
            $true
        }
    }
    $softwareList = @()
    foreach ($agent in $agentsResult) {
        $softwareResult = (Invoke-RestMethod -Method 'Get' -Uri "$url/software/$($agent.agent_id)/" -Headers $headers -ContentType 'application/json') 
        foreach ($softwareName in $softwareResult.software) {
            $softObj = New-Object psobject -Property @{
                Computer = $agent.hostname
                Software = $softwareName.name
            }
            $softwareList += $softObj
        }
    }
    return $softwareList
}

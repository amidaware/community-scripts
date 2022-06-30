<#
.Synopsis
    Example PowerShell script

.Description
    Hello World example for a PowerShell script in TRMM.
    $log if provided will output verbose logs with timestamps. This can be used to determine how long the installer took.

.Args
    -<param1> <string> #bound parameter
    -<agent> <string> #bound parameter
    -<site> <string> #bound parameter
    -<client> <string> #bound parameter
    [<string>] #Unbound parameter
    [<string>] #Unbound parameter

.Example
    Win_Hello_World.ps1 -Agent "{{agent.hostname}}" -Site "{{site.name}}" -Client "{{client.name}}" "Bound first parameter" "Unbound second parameter" Third-param Fourth
 #>

# Param needs to be the first statement or you will get an error:
#   The term 'param' is not recognized as the name of a cmdlet, function, script file, or operable program.
param (
    [string] $param1,
    [string] $agent,
    [string] $site,
    [string] $client
)

function Get-TimeStamp() {
    return Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
}

function Echo-Args {
    for($i = 0; $i -lt $args.length; $i++) {
        "Arg $i is <$( $args[$i] )>"
    }
}

if ($log) {
    # Skip the "Stdout:" line
    Write-Output ""
}

# This doesn't work
#Write-Output "$(Get-Timestamp) Command Line arguments:", $(Echo-Args)

Write-Output "$( Get-Timestamp ) Command Line arguments:", $( $args )
Write-Output ""

# See https://ss64.com/ps/psboundparameters.html
Write-Output "$( Get-Timestamp ) Bound parameters:", $PsBoundParameters.Values

if ($log) {
    Write-Output "$( Get-Timestamp ) Logging is enabled"
}

Write-Output ""
if (($param1 -eq $null) -or ($url.Length -eq 0)) {
    Write-Output "$( Get-Timestamp ) Param1 is not specified"
}
else {
    Write-Output "$( Get-Timestamp ) Param1 is $param1"
}

if (($agent -eq $null) -or ($agent.Length -eq 0)) {
    Write-Output "$( Get-Timestamp ) Agent is not specified"
}
else {
    Write-Output "$( Get-Timestamp ) Agent is $agent"
}

if (($site -eq $null) -or ($site.Length -eq 0)) {
    Write-Output "$( Get-Timestamp ) Site is not specified"
}
else {
    Write-Output "$( Get-Timestamp ) Site is $site"
}

if (($client -eq $null) -or ($client.Length -eq 0)) {
    Write-Output "$( Get-Timestamp ) Client is not specified"
}
else {
    Write-Output "$( Get-Timestamp ) Client is $client"
}


if ($log) {
    Write-Output "$( Get-Timestamp ) Finished!"
}

Exit(0)

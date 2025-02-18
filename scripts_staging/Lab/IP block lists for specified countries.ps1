<#
.SYNOPSIS
    This script downloads and processes IP block lists for specified countries 
    from ipdeny.com and creates corresponding inbound and/or outbound firewall 
    rules on the local machine using PowerShell cmdlets.

.DESCRIPTION
    The script allows users to automate the creation of firewall rules that block 
    IP ranges from specific countries or from a provided input file. It can delete 
    existing firewall rules matching the specified rule name and recreate them with 
    updated block lists.

    This script can be used to block IPs from countries with high levels of unwanted 
    traffic or suspected malicious activity.

    Sample of problematic Countries (often associated with cyberattacks, fraud, or high-risk traffic):
    - CN (China)
    - RU (Russia)
    - IN (India)
    - TR (Turkey)
    - BR (Brazil)
    - UA (Ukraine)
    - NG (Nigeria)
    - KR (South Korea)
    - PH (Philippines)
    - IR (Iran)

.PARAMETER Countries
    A comma-separated list of two-letter country codes (e.g.,  "ru,cn") to download 
    IP block lists for each specified country.

.PARAMETER InputFile
    Path to an input file containing IP ranges to block. Each line should contain 
    a valid IP range.

.PARAMETER RuleName
    Name for the firewall rule. If not provided, the base name of the input file 
    or zone file is used.

.PARAMETER ProfileType
    The firewall profile to apply the rules to. Default: "any". Options:
    - Domain
    - Private
    - Public
    - Any

.PARAMETER InterfaceType
    The type of network interface for the rule. Default: "any". Options:
    - Wired
    - Wireless
    - Any

.PARAMETER Direction
    Direction of traffic to block. Default: "Inbound". Options:
    - Inbound
    - Outbound
    - Both

.PARAMETER DeleteOnly
    If set, deletes all firewall rules matching "*xx.zone*".

.EXAMPLE
    -Countries "ru,cn"
    Downloads and processes IP block lists for Russia and China and creates corresponding inbound firewall rules

    -InputFile "C:\path\to\my-blocklist.txt" -RuleName "CustomBlock" -Direction Both
    Processes an input file containing IP ranges and creates both inbound and outbound rules.

    # Remove all rules with "*xx.zone*"
    -DeleteOnly

.NOTE
    V1 Author: Jason Fossen (http://www.sans.org/windows-security/) 20.Mar.2012 
    V2 Author: Vinahost release (https://cloudcraft.info) 15.Aug.2017
    V3 Author: SAN 28.01.25
    #public

.CHANGELOG
    28.01.25 New feature to set direction will default to inbound only to reduce the load on cpu, added feature to add countries in bulk, fixed deleteonly to remove all rules created, upgrade to PowerShell cmdlets for fw rules

.TODO
    add the postfix to rule name in every case to make sure DeleteOnly can catch them all

#>

param (
    [string] $Countries,
    [string] $InputFile,
    [string] $RuleName,
    [string] $ProfileType = "Any",
    [string] $InterfaceType = "Any",
    [ValidateSet("Inbound", "Outbound", "Both")]
    [string] $Direction = "Inbound",
    [switch] $DeleteOnly
)

# Function to delete existing firewall rules
function RemoveFirewallRules {
    param ([string]$Pattern)

    $RulesToDelete = Get-NetFirewallRule | Where-Object { $_.Name -like $Pattern }
    if ($RulesToDelete) {
        Write-Host "`nDeleting rules matching '$Pattern'..."
        $RulesToDelete | Remove-NetFirewallRule -Confirm:$false
        Write-Host "`nRules deleted successfully."
    } else {
        Write-Host "`nNo matching rules found."
    }
}

# If DeleteOnly is set, remove all rules matching *xx.zone*
if ($DeleteOnly) {
    RemoveFirewallRules -Pattern "*??.zone*"
    exit
}

# Function to process input file and create firewall rules
function ProcessFile {
    param (
        [string]$InputFile,
        [string]$RuleName,
        [string]$ProfileType,
        [string]$InterfaceType,
        [string]$Direction
    )

    $file = Get-Item $InputFile -ErrorAction SilentlyContinue
    if (-not $file) {
        Write-Host "`nFile $InputFile not found, quitting..." 
        exit
    }

    # Set default rule name if not provided
    if (-not $RuleName) { $RuleName = $file.BaseName }

    # Remove existing firewall rules for this specific rule name
    RemoveFirewallRules -Pattern "$RuleName-#*"

    # Load IP ranges from file
    $Ranges = Get-Content $file | Where-Object { ($_ -match '^[0-9a-fA-F]{1,4}[\.\:]') -and ($_ -match '\d') }
    if (-not $Ranges) {
        Write-Host "`nNo valid IP addresses found in $InputFile, quitting..."
        exit
    }

    $LineCount = $Ranges.Count
    Write-Host "`nLoaded $LineCount IP ranges from $InputFile..."

    # Define batch size for rules
    $MaxRangesPerRule = 200
    $RuleIndex = 1
    $StartIndex = 0

    # Process and create rules in batches
    while ($StartIndex -lt $LineCount) {
        $EndIndex = [Math]::Min($StartIndex + $MaxRangesPerRule, $LineCount)
        $IPBatch = $Ranges[$StartIndex..($EndIndex - 1)]
        $RuleSuffix = $RuleIndex.ToString("000")
        
        # Create rules based on direction
        if ($Direction -eq "Inbound" -or $Direction -eq "Both") {
            Write-Host "`nCreating inbound rule: $RuleName-#$RuleSuffix..."
            New-NetFirewallRule -Name "$RuleName-#$RuleSuffix" -DisplayName "$RuleName-#$RuleSuffix" -Direction Inbound -Action Block -RemoteAddress $IPBatch -Profile $ProfileType -InterfaceType $InterfaceType
        }

        if ($Direction -eq "Outbound" -or $Direction -eq "Both") {
            Write-Host "`nCreating outbound rule: $RuleName-#$RuleSuffix..."
            New-NetFirewallRule -Name "$RuleName-#$RuleSuffix" -DisplayName "$RuleName-#$RuleSuffix" -Direction Outbound -Action Block -RemoteAddress $IPBatch -Profile $ProfileType -InterfaceType $InterfaceType
        }
        
        $StartIndex += $MaxRangesPerRule
        $RuleIndex++
    }

    Write-Host "`nFirewall rules created successfully!"
}

# Validate input parameters
if (-not $Countries -and -not $InputFile) {
    Write-Host "Please specify at least one country or provide an input file." 
    exit
}

# Split the list of countries if provided
$CountryList = if ($Countries) { $Countries.Split(',') } else { @() }

if ($CountryList.Count -gt 0) {
    foreach ($Zone in $CountryList) {
        if ($Zone.Length -ne 2) {
            Write-Host "`nInvalid zone specified for '$Zone', skipping..." 
            continue
        }

        $Zone = $Zone.ToLower()
        $InputFile = "$Zone.zone.txt"
        
        Write-Host "`nDownloading IP block list for zone: $Zone..."
        try {
            Invoke-WebRequest -Uri "http://www.ipdeny.com/ipblocks/data/countries/$Zone.zone" -OutFile $InputFile -UseBasicParsing
        } catch {
            Write-Host "`nFailed to download IP block list for $Zone, skipping..."
            continue
        }

        # Process the downloaded input file
        ProcessFile -InputFile $InputFile -RuleName $Zone.zone -ProfileType $ProfileType -InterfaceType $InterfaceType -Direction $Direction
    }
} else {
    if ($InputFile) {
        ProcessFile -InputFile $InputFile -RuleName $RuleName -ProfileType $ProfileType -InterfaceType $InterfaceType -Direction $Direction
    }
}
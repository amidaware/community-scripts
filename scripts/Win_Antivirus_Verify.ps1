<#
    .SYNOPSIS
    Check if an antivirus is active and up to date

    .DESCRIPTION
    This script checks if an antivirus is active and up to date on a system. The user can specify a specific antivirus with the optional parameter "-antivirusName", otherwise the tool returns success if there is any active up to date antivirus on the system.

    .PARAMETER [antivirusName]
    The name of the antivirus to check for. Must match the "displayName" exactly.

    .EXAMPLE
    -antivirusName "AntivirusNameHere"

    .PARAMETER [customField]
    If this switch is provided, the script will only output the name of the antivirus.

    .EXAMPLE
    -customField

    .NOTES
    Version 1.0 4/7/2021 silversword
    https://mcpforlife.com/2020/04/14/how-to-resolve-this-state-value-of-av-providers/
    https://github.com/wortell/PSHelpers/blob/main/src/Public/Add-ProductStates.ps1
    Call with optional parameter "-antivirusName AntivirusNameHere" in order to check for a specific antivirus
    antivirusName must match the "displayName" exactly
    If no antivirusName parameter is specified, the tool returns success if there is any active up to date antivirus on the system
	Version 1.1 10/15/2023 dinger1986
	Added in -customfield to write AV name to a customfield

    OS Build must be greater than 14393 to support this script. If it's not it returns exit code 2
#>

param($antivirusName = "*", [switch]$customField)

[Flags()] enum ProductState {
    Off = 0x0000
    On = 0x1000
    Snoozed = 0x2000
    Expired = 0x3000
}

[Flags()] enum SignatureStatus {
    UpToDate = 0x00
    OutOfDate = 0x10
}

[Flags()] enum ProductOwner {
    NonMs = 0x000
    Windows = 0x100
}

[Flags()] enum ProductFlags {
    SignatureStatus = 0x000000F0
    ProductOwner = 0x00000F00
    ProductState = 0x0000F000
}

function Add-ProductStates {
    [CmdletBinding()]
    param (
       # This parameter can be passed from pipeline and can contain and array of collections that contain State or productstate members
        [Parameter(ValueFromPipeline)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $Products,
        # Product State contains a value (DWORD) that contains multiple bitflags and we use the productState flag (0000F000)
        [Parameter(Position = 0, ValueFromPipelineByPropertyName, ValueFromPipeline, HelpMessage = "The value (DWORD) containing the bitflags.")]
        [Alias("STATE")]
        [UInt32]$ProductState
    )

    begin {
        $results = $null
    }
    
    process {
        If ($Products -is [array]) {
            If ($Products.Count -gt 0) {
                If (Get-Member -inputobject $Products[0] -name "productState" -Membertype Properties) {
                    $results += $Products.PSObject.Copy()
                    foreach ($item in $Products) {
                        If ($results.Where({ $_.instanceGuid -eq $item.instanceGuid }).Properties.name -notmatch "state") {                       
                            $results.Where({ $_.instanceGuid -eq $item.instanceGuid }) | 
                            Add-Member -NotePropertyName state -NotePropertyValue $([ProductState]($item.productState -band [ProductFlags]::ProductState))
                        }
                        else {
                            Write-Error 'Could not add state property it already exists...'
                        }
                        If ($results.Where({ $_.instanceGuid -eq $item.instanceGuid }).Properties.name -notmatch "signatureStatus") {                       
                            $results.Where({ $_.instanceGuid -eq $item.instanceGuid }) | 
                            Add-Member -NotePropertyName signatureStatus -NotePropertyValue $([SignatureStatus]($item.productState -band [ProductFlags]::SignatureStatus))
                        }
                        else {
                            Write-Error 'Could not add signatureStatus property it already exists...'
                        }
                    }
                }
            }
        }
        If ($ProductState -and (-not $Products)) {
            If ($results.Properties.name -notmatch "enabled") {
                $results += New-Object PSObject -Property @{
                    state           = $([ProductState]($item.productState -band [ProductFlags]::ProductState))
                    signatureStatus = $([SignatureStatus]($item.productState -band [ProductFlags]::SignatureStatus))
                }
            }
        }
    }
    
    end {
        If ($results) {
            return $results
        }
    }
}

if ([environment]::OSVersion.Version.Build -le 14393) {
    write-host "Antivirus check not supported on this OS. Returning Exit Code 2."
    exit 2
}

$return = Get-CimInstance -Namespace root/SecurityCenter2 -className AntivirusProduct | 
Where-Object { 
         ($_.displayName -like $antivirusName) -and
         (($_.productState -band [ProductFlags]::ProductState) -eq [ProductState]::On) -and 
         (($_.productState -band [ProductFlags]::SignatureStatus) -eq [SignatureStatus]::UpToDate) 
} 

Write-Host "Antivirus selection: $antivirusName"
if ($return) {
    if ($customField) {
        # Only output the name of the first antivirus
        $return[0].displayName
        exit 0
    } else {
        Write-Host "Antivirus active and up to date"      
        $return
    }
}
else { 
    Write-Host "Antivirus issue!"
    Get-CimInstance -Namespace root/SecurityCenter2 -className AntivirusProduct | Add-ProductStates
    exit 1 
}

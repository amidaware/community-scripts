$gpath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$gname = 'DisableOSUpgrade'

<#
.SYNOPSIS
    Tests if a registry key exists.
    Modified from source: https://www.jonathanmedd.net/2014/02/testing-for-the-presence-of-a-registry-key-and-value.html
    Added by dinger1986 script checks written by Brodur
#>
function Test-RegistryValue {
    param (
    # The path to the registry key.
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Path,

    # The registry key to check the presence of.
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Value
    )

    try {
        Get-ItemProperty -Path $Path -Name $Value -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# --- Main Body --- #

# Check if the registry key exists.
if(!(Test-RegistryValue -path $gpath -Value $gname)){
    Write-Output "Registry key '$gpath\$gname' does not exist, attempting to create it."
    try {
        # Try to create it.
        New-ItemProperty -Path $gpath -Name $gname -Value 1 -PropertyType DWord
        Write-Output "Registry created."
        EXIT 0
    }
    catch {
        Write-Output "An error has occured."
        Write-Output $_
        EXIT 1
    }
}

# Check if the registry key has the correct value.
if((Get-ItemPropertyValue -Path $gpath -Name $gname) -eq 1){
    Write-Output "Registry key '$gpath\$gname' has value 1, the upgrade should be disabled."
    EXIT 0
}

# Try to correct the registry key if the value is incorrect.
else {
    Write-Output "Registry key '$gpath\$gname' exists, but the value is not 1. Changing it."
    try {
        Set-ItemProperty -Path $gpath -Name $gname -Value 1
        Write-Output "Registry updated."
        EXIT 0
    }
    catch {
        Write-Output "An error has occured."
        Write-Output $_
        EXIT 1
    }
}

<#
    .SYNOPSIS
    This script enables Active Directory Recycle Bin feature for the current domain.

    .DESCRIPTION
    Only run on a domain controller. This script checks whether the Recycle Bin feature is enabled for the current domain in Active Directory.

    .PARAMETER adRecycleBinScope
    The scope of the Recycle Bin feature to check. This parameter is obtained by running the Get-ADOptionalFeature cmdlet.

    .PARAMETER ADDomain
    The name of the Active Directory domain to check. This parameter is obtained by running the Get-ADDomain cmdlet.

    .PARAMETER ADInfraMaster
    The name of the infrastructure master for the domain. This parameter is obtained by running the Get-ADDomain cmdlet.

    .OUTPUTS
    This script does not output any objects.

    .EXAMPLE
    PS C:> .\Enable-ADRecycleBin.ps1

    bash
    Copy code
    This example runs the script to enable the Recycle Bin feature for the current domain in Active Directory.
    .EXAMPLE
    PS C:> .\Enable-ADRecycleBin.ps1 -ADDomain "contoso.com"

    bash
    Copy code
    This example runs the script to enable the Recycle Bin feature for the "contoso.com" domain in Active Directory.
    .NOTES
    Version: 1.0
#>

$adRecycleBinScope = Get-ADOptionalFeature -Identity 'Recycle Bin Feature' | Select -ExpandProperty EnabledScopes
$ADDomain = Get-ADDomain | Select -ExpandProperty Forest
$ADInfraMaster = Get-ADDomain | Select-Object InfrastructureMaster

if ($adRecycleBinScope -eq $null) {
    Write-Host "Recycle Bin Disabled"
    Write-Host "Attempting to enable AD Recycle Bin"
    Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target $ADDomain -Server $ADInfraMaster.InfrastructureMaster -Confirm:$false
    Write-Host "AD Recycle Bin enabled for domain $($ADDomain)"
}
else {
    Write-Host "Recycle Bin already Enabled For: $($ADDomain)`n Scope: $($adRecycleBinScope)"
}
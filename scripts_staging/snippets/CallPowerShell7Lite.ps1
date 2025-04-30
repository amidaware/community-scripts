<#
.SYNOPSIS
    Ensures the script is executed using PowerShell 7 or higher.

.DESCRIPTION
    This script verifies whether it is running in a PowerShell 7+ environment. 
    If not, and if PowerShell 7 (pwsh) is available on the system, it re-invokes itself using pwsh, passing along any parameters.
    If pwsh is not found, the script outputs a message and exits with an error code.
    Once running in PowerShell 7 or higher, it sets the output rendering mode to plaintext for consistent formatting.

.NOTES
    Author: SAN
    Date: 29/04/2025
    #public
#>


if (!($PSVersionTable.PSVersion.Major -ge 7)) {
  if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    pwsh -File "`"$PSCommandPath`"" @PSBoundParameters
    exit $LASTEXITCODE
  } else {
    Write-Output "PowerShell 7 is not available"
    exit 1
  }
}
$PSStyle.OutputRendering = "plaintext"

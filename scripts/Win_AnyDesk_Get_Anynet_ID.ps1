<#
    .SYNOPSIS
    This script extracts the AnyDesk ID from the system.conf file in the AnyDesk application directory.

    .DESCRIPTION
    This script searches for the system.conf file in the AnyDesk application directory and extracts the AnyDesk ID from it.

    .OUTPUTS
    Returns the AnyDesk ID as a string.

    .NOTES
    Version: 1.0 6/30/2021 Samuel Meuchel
#>

$Paths = @($Env:APPDATA, $Env:ProgramData, $Env:ALLUSERSPROFILE)

foreach ($Path in $Paths) {
    If (Test-Path $Path\AnyDesk) {
        $GoodPath = $Path
    }
}

$SystemFile = get-childitem -Path $GoodPath -Filter "system.conf" -Recurse -ErrorAction SilentlyContinue

$ConfigPath = $SystemFile.FullName

$ResultsIdSearch = Select-String -Path $ConfigPath -Pattern ad.anynet.id

$Result = @($ResultsIdSearch -split '=')

$Result[1]

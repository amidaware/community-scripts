# Retrieve Supremo ID from TRMM agent.

$SupremoVersionsNums = @('4', '')
$RegPaths = @('HKLM:\SOFTWARE\Wow6432Node\Supremo')
$Paths = @(foreach ($SupremoVersionsNum in $SupremoVersionsNums) {
        foreach ($RegPath in $RegPaths) {
            $RegPath + $SupremoVersionsNum
        }
    })

foreach ($Path in $Paths) {
    If (Test-Path $Path) {
        $GoodPath = $Path
    }
}

foreach ($FullPath in $GoodPath) {
    If ($null -ne (Get-Item -Path $FullPath).GetValue('ClientID')) {
        $SupremoID = (Get-Item -Path $FullPath).GetValue('ClientID')
        $ErrorActionPreference = 'silentlycontinue'
    }
}

Write-Output $SupremoID
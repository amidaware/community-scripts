# Get RustDesk ID

$Paths = @($Env:APPDATA, $Env:ProgramData, $Env:ALLUSERSPROFILE)

foreach ($Path in $Paths) {
    If (Test-Path $Path\RustDesk) {
        $GoodPath = $Path
    }
}

$ConfigPath = $GoodPath + "\RustDesk\Config\RustDesk.toml"

$ResultsIdSearch = Select-String -Path $ConfigPath -Pattern id

$Result = @($ResultsIdSearch -split '=')

$Result[1]
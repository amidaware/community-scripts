#public
#grab public id of restdesk to set a custom field

#V1
$ErrorActionPreference= 'silentlycontinue'

cd $env:ProgramFiles\RustDesk\
.\RustDesk.exe --get-id | out-host

exit

#V2
$ErrorActionPreference = 'SilentlyContinue'
$maxAttempts = 40
$attempt = 0

# Change directory to RustDesk install folder
Set-Location "$env:ProgramFiles\RustDesk"

while ($attempt -lt $maxAttempts) {
    $output = .\RustDesk.exe --get-id

    if ($output -and $output.Trim() -ne "") {
        Write-Host "Public ID obtained: $output"
        break
    } else {
        Write-Host "Attempt $($attempt + 1): No ID received, retrying in 30 seconds..."
        Start-Sleep -Seconds 30
        $attempt++
    }
}

if ($attempt -eq $maxAttempts) {
    Write-Host "Failed to get RustDesk ID after 20 minutes."
    exit 1
}

Write-Host "$output"

exit
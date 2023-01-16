# This is an untested and probably non-functional script. Going to rebuild in python once rustdesk gets its flutter rewrite

$Source = "https://github.com/rustdesk/rustdesk/releases/download/1.1.9/rustdesk-1.1.9-windows_x64.zip"
$SourceDownloadLocation = "C:\ProgramData\TacticalRMM\temp"
$SourcezipFile = "$SourceDownloadLocation\rustdesk.zip"
$SourceInstallFile = "$SourceDownloadLocation\rustdesk\rustdesk-1.1.9-putes.exe"
$ProgressPreference = 'SilentlyContinue'

# Download File
If (Test-Path -Path $SourcezipFile -PathType Leaf) {
    Write-Output "File already downloaded"
}
else {
    If (!(test-path $SourceDownloadLocation)) {
        New-Item -Path $SourceDownloadLocation -ItemType directory
    }
    Invoke-WebRequest $Source -OutFile $SourcezipFile

    Write-Output "File download complete"
}

# Extract files
expand-archive $SourcezipFile

# Install Rustdesk
$proc = Start-Process "$SourceInstallFile" -ArgumentList "--silent-install" -PassThru
Wait-Process -InputObject $proc
if ($proc.ExitCode -ne "0") {
    Write-Warning "Exited with error code: $($proc.ExitCode)"
    Exit 1
}
else {
    Write-Output "Successful install with exit code: $($proc.ExitCode)"
    # Cleanup archive
    Remove-Item "$SourcezipFile"
    Remove-Item -Path "$SourceInstallFile"
    Exit 0
}

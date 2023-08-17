# https://stackoverflow.com/questions/73272154/mcafee-consumer-product-removal-silent-script

$systemTmp = [System.Environment]::GetEnvironmentVariable('TEMP','Machine')

# https://devblogs.microsoft.com/powershell-community/borrowing-a-built-in-powershell-command-to-create-a-temporary-folder/
Function New-TemporaryFolder {
    # Make a new folder based upon a TempFileName
    $systemTmp = [System.Environment]::GetEnvironmentVariable('TEMP','Machine')
    $T="$($systemTmp)\tmp$([convert]::tostring((get-random 65535),16).padleft(4,'0')).tmp"
    if (Test-Path -Path $T -PathType Leaf) {
        Write-Output "Directory with random number exists: ${T}"
        Exit(1)
    }
    New-Item -ItemType Directory -Path $T
}

$tmpDir = New-TemporaryFolder

# Download
$Uri = "https://silentinstallhq.com/wp-content/uploads/2022/06/MCPR.zip"
$zipFile = "$tmpDir\MCPR.zip"
if (-not (Test-Path -Path $zipFile -PathType Leaf)) {
    Invoke-WebRequest -Uri $Uri -OutFile $zipFile -verbose
}

if (-not (Test-Path -Path "$($tmpDir)\MCPR.exe")) {
    Expand-Archive -Path $zipFile -DestinationPath $tmpDir
    if (-not (Test-Path -Path "$($tmpDir)\MCPR.exe")) {
        Write-Output "Failed to extract ZIP file"
        Exit(1)
    }
}

Get-ChildItem "$tmpDir"

# Start the process to extract the files
Start-Process "$($tmpDir)\MCPR.exe" -Verb RunAs -Verbose
Start-Sleep -Seconds 5
Get-Process -Name "McClnUI"

$nsTemp = Get-ChildItem -Path $systemTmp -Include mccleanup.exe -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object CreationTime |
    Select-Object -First 1

if (-not (Test-Path -Path $nsTemp)) {
    Write-Output "Could not find temporary folder: $($nsTemp)"
    #Exit(1)
}

$mcprDir = "$($tmpDir)\MCPR"
Write-Output "tempFolder: $nsTemp"
Write-Output "mcprDir: $mcprDir"

# Copy the files before killing the process
if (-not (Test-Path -Path $mcprDir)) {
    Copy-Item -Path $nsTemp.DirectoryName -Destination $mcprDir -Recurse
}
Stop-Process -Name "McClnUI"

# Remove the log if exists
if (Test-Path -Path $mcprDir\mccleanup.log) {
    Remove-Item $mcprDir\mccleanup.log
}

cd $mcprDir
Start-Process -FilePath "$mcprDir\mccleanup.exe" -ArgumentList '-p StopServices,MFSY,PEF,MXD,CSP,Sustainability,MOCP,MFP,APPSTATS,Auth,EMproxy,FWdiver,HW,MAS,MAT,MBK,MCPR,McProxy,McSvcHost,VUL,MHN,MNA,MOBK,MPFP,MPFPCU,MPS,SHRED,MPSCU,MQC,MQCCU,MSAD,MSHR,MSK,MSKCU,MWL,NMC,RedirSvc,VS,REMEDIATION,MSC,YAP,TRUEKEY,LAM,PCB,Symlink,SafeConnect,MGS,WMIRemover,RESIDUE -v -s' -WindowStyle Normal
Get-Process -Name "mccleanup" -ErrorAction SilentlyContinue | Wait-Process

#Remove-Item -Recurse $tmpDir
Get-Content -Tail 50 $mcprDir\mccleanup.log

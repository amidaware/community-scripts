
## Measures the speed of the download, can only be ran on a PC running Windows 10 or a server running Server 2016+, plan is to add uploading also
## Majority of this script has been copied/butchered from https://www.ramblingtechie.co.uk/2020/07/13/internet-speed-test-in-powershell/
# MINIMUM ACCEPTED THRESHOLD IN mbps 
$mindownloadspeed = 20
$minuploadspeed = 4

# File to download you can find download links for other files here https://speedtest.flonix.net
$downloadurls = @(
    "https://raw.githubusercontent.com/jamesward/play-load-tests/master/public/10mb.txt"
)

# SIZE OF SPECIFIED FILE IN MB (adjust this to match the size of your file in MB as above)
$sizes = @(
    10,
    10
)

# Name of Downloaded file
$localfile = "SpeedTest.bin"

# WEB CLIENT VARIABLES
$webclient = New-Object System.Net.WebClient

# Variable to track if download was successful
$downloadSuccessful = $false

for ($i = 0; $i -lt $downloadurls.Length; $i++) {
    $downloadurl = $downloadurls[$i]
    $size = $sizes[$i]
    
    # Write-Output "trying $downloadurl"
    try {
        #RUN DOWNLOAD & CALCULATE DOWNLOAD SPEED
        $start_time = Get-Date
        # $a = Measure-Command -Expression { 
            $webclient.DownloadFile($downloadurl, $localfile)
        # }
        $end_time = Get-Date
        $downloadSuccessful = $true
        break # exits for loop
    } catch {
        Write-Output "Failed to download: $downloadurl : Trying the next URL..."
    }
}

if (-not $downloadSuccessful) {
    Write-Output "All download attempts failed."
    exit 1
}


$secs_taken = ($end_time - $start_time).TotalSeconds
$downloadspeed = ($size / $secs_taken) * 8
Write-Output "Time taken: $([Math]::Round($secs_taken, 2)) seconds | Download Speed: $([Math]::Round($downloadspeed, 2)) mbps"


#RUN UPLOAD & CALCULATE UPLOAD SPEED
#$uploadstart_time = Get-Date
#$webclient.UploadFile($UploadURL, $localfile) > $null;
#$uploadtimetaken = $((Get-Date).Subtract($uploadstart_time).Seconds)
#$uploadspeed = ($size / $uploadtimetaken) * 8
#Write-Output "Time taken: $uploadtimetaken second(s) | Upload Speed: $uploadspeed mbps"

#DELETE TEST DOWNLOAD FILE
Remove-Item -path $localfile

#SEND ALERTS IF BELOW MINIMUM THRESHOLD 
if ($downloadspeed -ge $mindownloadspeed) { 
    Write-Output "Speed is acceptable. Current download speed is above the threshold of $mindownloadspeed mbps" 
    exit 0
} else { 
    Write-Output "Current download speed is below the minimum threshold of $mindownloadspeed mbps" 
    exit 1
}

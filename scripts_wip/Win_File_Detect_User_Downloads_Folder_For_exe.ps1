# Can add day limits and gets error codes out of Invote-AsCurrentUser
# Save Grandma and Grandpa from scammers put as check every 30mins with sms alert


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (Get-Module -ListAvailable -Name RunAsUser) {
    #Write-Output "RunAsUser Already Installed"
} 
else {
    Write-Output "Installing RunAsUser"
    Install-Module -Name RunAsUser -Force
}

Invoke-AsCurrentUser -scriptblock {

    $targetDir = "$($env:USERPROFILE)\Downloads\"
    # Write-Output "targetDir is $targetDir" | Out-File -append -FilePath c:\temp\raulog.txt
    # $targetDir = "c:\temp"
    $pattern = "*.exe"
    # get-ChildItem $targetDir | Where-Object {($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-10))}
    # get-ChildItem $targetDir | Where-Object {($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-1))}

    If (!(get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-100)) })) {
        Write-Output "No .exes in the last x days" | Out-File -append -FilePath c:\temp\raulog.txt
    }
    else {
        Write-Output (get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-100)) }) | Out-File -append -FilePath c:\temp\raulog.txt
        Write-Output "exit 1" | Out-File -append -FilePath c:\temp\exit1.txt
    }
    Write-Output "Finished Run" | Out-File -append -FilePath c:\temp\raulog.txt

}
$exitdata = Get-Content -Path "c:\temp\raulog.txt"
Write-Output $exitdata

If ((Test-Path -Path "c:\temp\exit1.txt" -PathType Leaf) -eq $false ) {
    
    Write-Output "no exes"
    Remove-Item -path "c:\temp\raulog.txt"
    exit 0

}
Else {

    Write-Output 'there be exes'
    Remove-Item -path "c:\temp\raulog.txt"
    Remove-Item -path "c:\temp\exit1.txt"
    exit 1
}
https://discord.com/channels/736478043522072608/744281869499105290/1049901850431860817

function Get-BootInformation {
    $BootMode = $env:firmware_type
    $SBStatus = Confirm-SecureBootUEFI
    Set-ExecutionPolicy unrestricted
    if (($BootMode -eq "UEFI") -and ($SBStatus -eq $True)) {
        Write-Host "This system has UEFI, and Secure Boot is on. This is OK."
        exit 0
    }
    elseif (($BootMode -eq "UEFI") -and ($SBStatus -eq $False)) {
        Write-Host "This system has UEFI, but Secure Boot is off. This is not OK."
        exit 1
    }
    elseif (($BootMode -eq "Legacy")) { 
        Write-Host "This system is Legacy, therefore it does not support Secure Boot. This is OK."
        exit 0
    }
}

Get-BootInformation

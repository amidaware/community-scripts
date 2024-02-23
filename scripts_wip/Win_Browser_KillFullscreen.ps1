# TODO Not functional, needs work. Trying to stop full screen tech scam sites from going fullscreen.

Function InstallRequirements {
    # Check if NuGet is installed
    if (!(Get-PackageProvider -Name NuGet -ListAvailable)) {
        Write-Output "Nuget installing"
        Install-PackageProvider -Name NuGet -Force
    }
    else {
        Write-Output "Nuget already installed"
    }
    if (-not (Get-Module -Name RunAsUser -ListAvailable)) {
        Write-Output "RunAsUser installing"
        Install-Module -Name RunAsUser -Force
    }
    else {
        Write-Output "RunAsUser already installed"
    }
}
InstallRequirements

############# Machine Settings #############################

function Set-RegistryValue ($registryPath, $name, $value) {
    if (!(Test-Path -Path $registryPath)) {
        # Key does not exist, create it
        New-Item -Path $registryPath -Force | Out-Null
    }
    # Set the value
    Set-ItemProperty -Path $registryPath -Name $name -Value $value
}

#FukOffAutoFullscreen
$RegistryPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
Set-RegistryValue -registryPath $RegistryPath -name "FullscreenAllowed" -value 0

############# User Settings #############################

Invoke-AsCurrentUser -scriptblock {

    function Set-RegistryValue ($registryPath, $name, $value) {
        if (!(Test-Path -Path $registryPath)) {
            # Key does not exist, create it
            New-Item -Path $registryPath -Force | Out-Null
        }
        # Set the value
        Set-ItemProperty -Path $registryPath -Name $name -Value $value
    }

    # Kill Full screen in Firefox
    $RegistryPath = "HKCU:\Software\Mozilla\Firefox\Preferences"
    Set-RegistryValue -registryPath $RegistryPath -name "full-screen-browsing" -value 0

}
#Checking if ToastReboot:// protocol handler is present
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -erroraction silentlycontinue | out-null
$ProtocolHandler = get-item 'HKCR:\ToastReboot' -erroraction 'silentlycontinue'
if (!$ProtocolHandler) {
    #create handler for reboot
    New-item 'HKCR:\ToastReboot' -force
    set-itemproperty 'HKCR:\ToastReboot' -name '(DEFAULT)' -value 'url:ToastReboot' -force
    set-itemproperty 'HKCR:\ToastReboot' -name 'URL Protocol' -value '' -force
    new-itemproperty -path 'HKCR:\ToastReboot' -propertytype dword -name 'EditFlags' -value 2162688
    New-item 'HKCR:\ToastReboot\Shell\Open\command' -force
    set-itemproperty 'HKCR:\ToastReboot\Shell\Open\command' -name '(DEFAULT)' -value 'C:\Windows\System32\shutdown.exe -r -t 00' -force
}

# Always run the shutdown command
Invoke-Expression -Command "shutdown /r /t 600"

# Check if NuGet is installed
if (!(Get-PackageProvider -Name NuGet -ListAvailable)) {
    Write-Output "Nuget installing"
    Install-PackageProvider -Name NuGet -Force
}
else {
    Write-Output "Nuget already installed"
}
if (-not (Get-Module -Name BurntToast -ListAvailable)) {
    Write-Output "BurntToast installing"
    Install-Module -Name BurntToast -Force
}
else {
    Write-Output "BurntToast already installed"
}

if (-not (Get-Module -Name RunAsUser -ListAvailable)) {
    Write-Output "RunAsUser installing"
    Install-Module -Name RunAsUser -Force
}
else {
    Write-Output "RunAsUser already installed"
}

invoke-ascurrentuser -scriptblock {
 
    $heroimage = New-BTImage -Source 'https://imageurl.png' -HeroImage
    $Text1 = New-BTText -Content  "Message from Computer Dudez"
    $Text2 = New-BTText -Content "Emergency Updates have been installed for a critical bug and a reboot is required. Please reboot now. Call if you have any questions. 867-5309"
    $Button = New-BTButton -Content "Snooze" -snooze -id 'SnoozeTime'
    $Button2 = New-BTButton -Content "Reboot now" -Arguments "ToastReboot:" -ActivationType Protocol
    $5Min = New-BTSelectionBoxItem -Id 5 -Content '5 minutes'
    $10Min = New-BTSelectionBoxItem -Id 10 -Content '10 minutes'
    $Items = $5Min, $10Min
    $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 10 -Items $Items
    $action = New-BTAction -Buttons $Button, $Button2 -inputs $SelectionBox
    $Binding = New-BTBinding -Children $text1, $text2 -HeroImage $heroimage
    $Visual = New-BTVisual -BindingGeneric $Binding
    $Content = New-BTContent -Visual $Visual -Actions $action
    Submit-BTNotification -Content $Content
}
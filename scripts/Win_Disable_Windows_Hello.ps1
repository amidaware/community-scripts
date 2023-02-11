If (!(Test-Path HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork)) {
    New-Item HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork
}

New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork -Name Enabled -Value 0 -PropertyType DWORD
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork -Name DisablePostLogonProvisioning -Value 1 -PropertyType DWORD

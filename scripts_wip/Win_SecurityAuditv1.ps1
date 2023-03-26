Write-Host "Security Audit"
Write-Host "--------------"
Write-Host "Date:             $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")"
Write-Host "Computer Name:    $(("{0}\{1}" -f $computerSystem.Domain, $computerSystem.Name))"
Write-Host "$((get-WMiObject -computername $env:computername -Class win32_operatingSystem).caption) Build $(([System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Windows\system32\kernel32.dll")).FileBuildPart)"

$computerSystem = Get-CimInstance Win32_ComputerSystem
Write-Output "Computer Na$(("{0}\{1}" -f $computerSystem.Domain, $computerSystem.Name))"

$BuildNo = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Windows\system32\kernel32.dll")).FileBuildPart
if ($BuildNo -lt 7601) {
    write-host "WARNING: This computer is pre-Windows 7 SP1/Server 2008 R2."
    write-host "Microsoft does not support this operating system, therefore, it will not receive any security updates."
    write-host "Security Audit: FAILED"
    Exit 1
}

if ($BuildNo -eq 7601) {
    write-host "WARNING: This computer is Windows 7 SP1/Server 2008 R2."
    write-host "Microsoft does not support this operating system as of January 14 2020, therefore, it will not receive any security updates."
    write-host "Security Audit: FAILED"
    Exit 1
}

if ($BuildNo -eq 9200) {
    write-host "WARNING: This computer is Windows 8.0/Server 2012 has been discontinued by Microsoft."
    write-host "Microsoft does not support this operating system therefore, it will not receive any security updates."
    write-host "Security Audit: FAILED"
    Exit 1
}

write-host "---------------------- Account Audit ----------------------"

# Check for local "Administrator" account
if ((Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='$true' AND SID LIKE '%-500'").disabled) {
    write-host "- The 'Administrator' account is disabled."
}
else {
    write-host "X - WARNING: The 'Administrator' account is enabled. You should never have the account 'Administrator' enabled."
}


if ((Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty PartOfDomain) -eq $true) {
    # Computer is in a domain.
    # Check for local accounts
    $localAccountExists = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='$true'"
    If ( -not $localAccountExists ) {
        Write-Host "$($localAccountExists)"
        write-host "- No Local Accounts."
    }
    else {
        # Check for enabled guest account
        if ((Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='$true' AND SID LIKE '%-501'").disabled) {
            write-host "- The Guestasdfasdfasfd account is disabled."
        }
        else {
            write-host "X - WARNING: The Guest account is enabled. "
        }
    }

}
else {
    # Computer is not in a domain.
    Write-Host "This computer is not in a domain."
    # Get the local administrators group object
    $adminsGroup = [ADSI]"WinNT://./Administrators"

    # Get the members of the administrators group
    $admins = $adminsGroup.Members() | foreach { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) }

    # Filter out disabled accounts
    $admins = $admins | where { $_ -notin 'Administrator', 'Guest' } | foreach {
        $user = [ADSI]"WinNT://./$_,user"
        if (-not $user.UserFlags.Contains('AccountDisabled')) {
            $_
        }
    }

    # Check if any members were found and print the list of administrators
    if ($admins.Count -eq 0) {
        Write-Host "No local administrators found."
    }
    else {
        Write-Host "Local administrators:"
        $admins | foreach { Write-Host "- $_" }
    }
}


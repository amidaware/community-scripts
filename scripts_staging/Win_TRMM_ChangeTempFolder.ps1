<#
.SYNOPSIS
   Script to create directories and set security ACLs for TacticalRMM.

.DESCRIPTION
   This script creates two directories, sets the security ACLs for each directory, and creates registry keys for the TacticalRMM agent to use.

.NOTES
   Version: 1.0 6/2/2023 from Yasd in Discord
#>


$WinTmpDir = "C:\Windows\Temp\TacticalRMM"
$WinRunAsUserTmpDir = "C:\ProgramData\TacticalRMM"

$Result = 0

# WinTmpDir first..

$expected_sd = 'O:SYG:SYD:PAI(A;OICIIO;FA;;;CO)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)' # creator owner, administrators and system have full control, nothing else.
$expected_sd_pattern = 'O:SYG:(?:(SY|S-1-5-21-.*-513))D:PAI\(A;OICIIO;FA;;;CO\)\(A;OICI;FA;;;SY\)\(A;OICI;FA;;;BA\)' # alternative match, as the (legacy) primary group value may be different but this doesn't matter

# if WinTmpDir doesn't exist then create and ACL it
if (! (Test-Path $WinTmpDir)) {
    New-Item -ItemType Directory -Path $WinTmpDir
    $acl = Get-Acl -Path $WinTmpDir
    $acl.SetSecurityDescriptorSddlForm($expected_sd)
    Set-Acl -Path $WinTmpDir -AclObject $acl
}

# test WinTmpDir Security ACL matches our expected value
$sd = (Get-Acl $WinTmpDir).Sddl
if ($sd -notmatch $expected_sd_pattern) { Write-Host "WARNING: Security ACL on $WinTmpDir does not match expected value. Review permissions!"; $Result = 1}


# ..now WinRunAsUserTmpDir..

$expected_sd = 'O:BAG:SYD:AI(A;OICIID;FA;;;SY)(A;OICIID;FA;;;BA)(A;OICIIOID;GA;;;CO)(A;OICIID;0x1200a9;;;BU)(A;CIID;DCLCRPCR;;;BU)' # inherited. creator owner, administrators and system have full control, users have read/write.
$expected_sd_pattern = 'O:BAG:(?:(DU|SY|S-1-5-21-.*-513))D:AI\(A;OICIID;FA;;;SY\)\(A;OICIID;FA;;;BA\)\(A;OICIIOID;GA;;;CO\)\(A;OICIID;0x1200a9;;;BU\)\(A;CIID;DCLCRPCR;;;BU\)' # alternative match, as the (legacy) primary group value may be different but this doesn't matter

if (! (Test-Path $WinRunAsUserTmpDir)) {
    New-Item -ItemType Directory -Path $WinRunAsUserTmpDir
    $acl = Get-Acl -Path $WinRunAsUserTmpDir
    $acl.SetSecurityDescriptorSddlForm($expected_sd)
    Set-Acl -Path $WinRunAsUserTmpDir -AclObject $acl
}

# test WinRunAsUserTmpDir Security ACL matches our expected value
$sd = (Get-Acl $WinRunAsUserTmpDir).Sddl
if ($sd -notmatch $expected_sd_pattern) { Write-Host "WARNING: Security ACL on $WinRunAsUserTmpDir does not match expected value. Review permissions!"; $Result = 1}

# if both folders have the correct Security ACLs create the registry keys instructing the TRMM agent to use them
if ($Result -eq 0) {
    $key = "HKLM:\SOFTWARE\TacticalRMM"
    New-ItemProperty -Path $key -Name WinTmpDir -Value $WinTmpDir
    New-ItemProperty -Path $key -Name WinRunAsUserTmpDir -Value $WinRunAsUserTmpDir
}

exit $Result
<#
.Synopsis
    Completely removes internet explorer from the system.
.EXAMPLE
   Win_IE_Remove
   Win_IE_Remove -ForceReboot
.NOTES
   Version: 1
   Author: redanthrax
   Creation Date: 7-5-2023
#>


Param(
    [switch]$ForceReboot
)

function Win_IE_Remove {
    [CmdletBinding()]
    Param(
        [switch]$ForceReboot
    )

    Write-Output "Removing Internet Explorer."
    #check if process running
    $ie = Get-Process iexplore.exe -ErrorAction SilentlyContinue
    if ($ie) {
        Write-Output "Found internet explorer running, attempting task end."
        $ie.CloseMainWindow()
        Start-Sleep -Seconds 5
        if (-Not($ie.HasExited)) {
            $ie | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }

    #uninstall, fallback to dism on catch
    try {
        Write-Output "Checking to see if Internet Explorer enabled."
        $check = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "Internet-Explorer-Optional-amd64" }
        switch ($check.State) {
            "Enabled" {
                Write-Output "Attempting Optional Feature removal"
                Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart | Out-Null
                $check = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "Internet-Explorer-Optional-amd64" }
            }
            "Disabled" {
                Write-Output "Windows Feature Internet Explorer disabled"
            }
            "DisablePending" {
                Write-Output "Waiting for computer reboot, reboot and run script again to complete"
            }
        }

        if (-not($check)) {
            Write-Output "Windows Feature Internet Explorer doesn't exist"
        }
    }
    catch {
        Write-Output "Attempting DISM uninstall"
        Start-Process -Wait -FilePath dism -Verb RunAs -ArgumentList '/online', '/disable-feature', '/featurename:Internet-Explorer-Optional-amd64'
    }

    if ($check.State -eq "DisablePending" -and $ForceReboot) {
        Restart-Computer -Force
    }

    if ($check.State -eq "Disabled" -or -not($check)) {
        # remove the exe
        Write-Output "Checking for iexplore.exe"
        $paths = @('C:\Program Files\Internet Explorer\iexplore.exe',
            'C:\Program Files (x86)\Internet Explorer\iexplore.exe')
        foreach ($path in $paths) {
            if (Test-Path -Path $path -PathType Leaf) {
                try {
                    Write-Output "Found iexplore.exe at $path - removing"
                    $ACL = Get-ACL -Path $path
                    $Group = New-Object System.Security.Principal.NTAccount("NT Authority", "SYSTEM")
                    $ACL.SetOwner($Group)
                    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT Authority\SYSTEM", "FullControl", "Allow")
                    $ACL.SetAccessRule($AccessRule)
                    Set-Acl -Path $path -AclObject $ACL
                    Remove-Item -Path $path -Force
                }
                catch {
                    Write-Output "Unable to remove iexplore.exe from $path - $_"
                }
            }
            else {
                Write-Output "Did not find iexplore.exe at $path"
            }
        }
    }
}



if (-not(Get-Command 'Win_IE_Remove' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    ForceReboot = $ForceReboot
}


Win_IE_Remove @scriptArgs
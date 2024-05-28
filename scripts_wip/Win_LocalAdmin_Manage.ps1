<#
.Synopsis
   Manages the local Administrator account and sets the password based on the clients custom field.
.DESCRIPTION
   This script will check the local administrators group for a list of users in the group.
   It will try and select the user called "Administrator". The script will also make sure
   the account is enabled. Once the admin account exists it will remove all others from the local
   administrators group.
.EXAMPLE
    Win_LocalAdmin_Manage -LocalAdminUser CompanyAdmin -LocalPassword Password123
.EXAMPLE
    Win_LocalAdmin_Manage -LocalAdminUser CompanyAdmin -LocalPassword Password124 -Enforce
.INSTRUCTIONS
    1. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, 
    create the following custom fields:
        a) LocalAdminUser as type text
        b) LocalAdminPassword as type text
    3. In Tactical RMM, Right-click on each client and select Edit. Fill in the LocalAdminPassword.
    4. Create the following script arguments
        a) -LocalAdminUser {{client.LocalAdminUser}}
        b) -LocalAdminPassword {{client.LocalAdminPassword}}
        c) -Enforce //Use this to always set the password on script run. Optional.
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2022-05-04
   Updated: 2023-10-24
#>

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "RMM Only Has Cleartext")]
Param(
    [Parameter(Mandatory)]
    [string]$LocalAdminUser,

    [Parameter(Mandatory)]
    [string]$LocalAdminPassword,

    [Parameter()]
    [switch]$Enforce
)

function Win_LocalAdmin_Manage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$LocalAdminUser,

        [Parameter(Mandatory)]
        [string]$LocalAdminPassword,

        [Parameter()]
        [switch]$Enforce
    )

    Begin {
        $userPrincipal = $null
    }

    Process {
        Try {
            $adminMembers = ([ADSI]"WinNT://localhost/Administrators,group").Members() | Foreach-Object { ([ADSI]$_).Path.Substring(8).split("/")[1] }
            if ($adminMembers | Where-Object { $_ -Match $LocalAdminUser }) {
                Write-Output "$LocalAdminUser exists."
                if ($Enforce) {
                    Write-Output "Removing all other admins from Administrator Group."
                    $adminMembers = $adminMembers | Where-Object { -Not([string]::IsNullOrWhiteSpace($_)) }
                    foreach ($adminMember in $adminMembers) {
                        if (-Not($adminMember -Match $LocalAdminUser)) {
                            if (Get-LocalUser | Where-Object { $_.Name -eq $adminMember }) {
                                if($adminMember -ne "Administrator") {
                                    Add-LocalGroupMember -Group "Users" -Member $adminMember
                                    Remove-LocalGroupMember -Group Administrators -Member $adminMember
                                }
                            }
                        }
                        else {
                            #ensure admin is the sid 500 account
                            Write-Output "Checking $LocalAdminUser account."
                            $matchAccount = Get-LocalUser | Where-Object { $_.Name -eq $adminMember }
                            if (-Not($matchAccount.SID -like "*-500")) {
                                #account exists but is not admin - remove
                                Write-Output "Removing $($matchAccount.Name) non-sid 500 account."
                                Remove-LocalUser $matchAccount
                                Exit 0
                            }
                        }
                    }

                    Write-Output "Enforce specified. Setting the password for $LocalAdminUser."
                    $adminUser = Get-LocalUser -Name $LocalAdminuser
                    $newPass = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
                    Set-LocalUser -SID $adminUser.SID -AccountNeverExpires -PasswordNeverExpires $true -Password $newPass
                }

                Exit 0
            }

            $adminSID = (Get-WmiObject -Class Win32_UserAccount -Filter "SID like '%-500'").SID
            if ($null -ne $adminSID) {
                Write-Output "Found administrator user."
                $userObject = Get-LocalUser -SID $adminSID
                Write-Output "Renaming local admin account to $LocalAdminUser."
                Rename-LocalUser -SID $userObject.SID -NewName $LocalAdminUser
                Write-Output "Setting local admin account password."
                $newPass = ConvertTo-SecureString $LocalAdminPassword -AsPlainText -Force
                Set-LocalUser -SID $userObject.SID -AccountNeverExpires -PasswordNeverExpires $true -Password $newPass
                Write-Output "Ensuring account is enabled."
                Enable-LocalUser -SID $userObject.SID
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
            Exit 1
        }
    }

    End {
        Write-Output "Local admin management complete."
        Exit 0
    }
}

if (-not(Get-Command 'Win_LocalAdmin_Manage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    LocalAdminUser     = $LocalAdminUser
    LocalAdminPassword = $LocalAdminPassword
    Enforce            = $Enforce
}
 
Win_LocalAdmin_Manage @scriptArgs
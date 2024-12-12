<#
.SYNOPSIS
    This script resets folder and file permissions by applying inherited permissions from the target folder and checks for permission mismatches across subfolders and files.

.DESCRIPTION
    The script retrieves the target folder path from an environment variable and ensures the folder exists. 
    It then gets the ACL (Access Control List) of the target folder and applies the inherited permissions to all subfolders and files within the target folder. 
    It also compares the ACLs of child items with their parent folder to identify permission mismatches. The script includes two main functions:
    - `Set-InheritedPermissions`: Resets permissions and inheritance on a folder or file.
    - `Compare-Acls`: Compares the ACLs of a child item with its parent to identify mismatched permissions.

.EXAMPLE 
    TARGETFOLDER=C:\TargetFolder


.NOTES
    Author: SAN
    Date: ???
    #public

.CHANGELOG


#>



# Get the target folder from environment variable
$TargetFolder = $env:TARGETFOLDER

if (-not (Test-Path -Path $TargetFolder)) {
    Write-Output "The specified path does not exist: $TargetFolder"
    exit
}

# Get the ACL of the target folder
$targetAcl = Get-Acl -Path $TargetFolder

# Function to reset permissions and inheritance
function Set-InheritedPermissions {
    param (
        [string]$Path
    )

    try {
        # Reset ACLs to match the target folder
        $acl = Get-Acl -Path $Path
        $acl.SetAccessRuleProtection($false, $true)  # Enable inheritance, remove explicit permissions
        Set-Acl -Path $Path -AclObject $targetAcl

        # Get the owner of the target folder
        $owner = $targetAcl.Owner
        # Set owner to be the same as the target folder
        $acl.SetOwner([System.Security.Principal.NTAccount]$owner)
        Set-Acl -Path $Path -AclObject $acl

        Write-Output "Reset permissions and ownership for: $Path"
    } catch {
        Write-Output "Failed to process permissions for: $Path"
    }
}

# Function to compare ACLs of child items with parent folder
function Compare-Acls {
    param (
        [string]$Path
    )

    try {
        $parentAcl = Get-Acl -Path (Get-Item -Path $Path).Parent.FullName
        $itemAcl = Get-Acl -Path $Path

        # Compare ACLs
        if ($itemAcl -ne $parentAcl) {
            Write-Output "Permission mismatch for: $Path"
        }
    } catch {
        Write-Output "Unreadable ACL or permission issue with: $Path"
    }
}

Write-Output "Processing folder: $TargetFolder"

# Set permissions for the target folder itself
Set-InheritedPermissions -Path $TargetFolder

# Process all subfolders and files to reset permissions
$items = Get-ChildItem -Path $TargetFolder -Recurse
foreach ($item in $items) {
    Set-InheritedPermissions -Path $item.FullName
}

Write-Output "`nScanning for files with unreadable or mismatched permissions..."

# Scan all subfolders and files to check for permission issues
foreach ($item in $items) {
    Compare-Acls -Path $item.FullName
}

Write-Output "Permission scan completed."
<#
   .SYNOPSIS
      Securely deletes a folder using the cipher command.

   .DESCRIPTION
      This PowerShell script securely deletes a folder using the cipher command in Windows.

   .PARAMETER FolderPath
      The path to the folder that you want to securely delete.

   .NOTES
      This operation cannot be undone, and the data will be permanently deleted. Ensure that you have administrator privileges before running this script. 
      Version 1.0 3/27/2023 silversword
#>

param(
   [string]$FolderPath
)

if (-not (Test-Path $FolderPath)) {
   Write-Output "Folder path not found: $FolderPath"
   exit 1
}

# Securely delete the folder
cipher /w:$FolderPath

Write-Output "Securely deleted folder: $FolderPath"
<#
.Synopsis
   Checks all FileSystem drives for an amount of space specified. Fails if less than space specified.
.DESCRIPTION
   Long description
   Checks all FileSystem drives for an amount of space specified (amount is converted to Gigabytes).
.EXAMPLE
    Confirm-DiskSpaceAvailable -Size 10
.EXAMPLE
    Confirm-DiskSpaceAvailable -Size 10 -Percent
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2022-04-05
#>

Param(
   [Parameter(Mandatory)]
   [int]$Size,

   [Parameter(Mandatory = $false)]
   [switch]$Percent
)

function Confirm-DiskSpaceAvailable {
   [CmdletBinding()]
   Param(
      [Parameter(Mandatory)]
      [int]$Size,

      [Parameter(Mandatory = $false)]
      [switch]$Percent
   )

   Begin {}

   Process {
      Try {
         $errors = 0
         $drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" -and $_.Used -gt 0 -and $_.Name.ToLower() -ne "temp" }
         foreach ($drive in $drives) {
            [string]$label = "GB"
            [double]$available = 0
            if ($Percent) {
               #Percent flag is set
               #Calculate percent of free space left on drive
               $available = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100,2)
               $label = "%"
            }
            else {
               $available = [math]::Round($drive.Free / 1Gb, 2)
            }

            if ($Size -gt $available) {
               Write-Output "$available $label space remaining on $($drive.Name)."
               $errors += 1
            }
         }
      }

      Catch {
         Write-Output "Error: ${$_.Exception}"
         Exit 1
      }
   }

   End {
      if ($errors -gt 0) {
         Exit 1
      }

      Write-Output "All disks have been checked and have more than or equal to $size $label space available."
      Exit 0
   }
}

if (-not(Get-Command 'Confirm-DiskSpaceAvailable' -errorAction SilentlyContinue)) {
   . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
   Size    = $Size
   Percent = $Percent
}

Confirm-DiskSpaceAvailable @scriptArgs
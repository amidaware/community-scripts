<#
.Synopsis
   Checks all FileSystem drives for an amount of space specified. Fails if less than space specified.
.DESCRIPTION
   Long description
   Checks all FileSystem drives for an amount of space specified (amount is converted to Gigabytes).
.EXAMPLE
    Win_Disk_Space_Check -Size 10
.EXAMPLE
    Win_Disk_Space_Check -Size 10 -Percent
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
         $drives = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" -and $_.Used -gt 0 }
         foreach ($drive in $drives) {
            $name = $drive.Name
            if ($Percent) {
               #Percent flag is set
               #Calculate percent of space left on drive
               $remainingPercent = [math]::Round($drive.Used / ($drive.Free + $drive.Used))
               
               if ($Size -gt $remainingPercent) {
                  Write-Output "$remainingPercent% space remaining on $name."
                  $errors += 1
               }
            }
            else {
               $free = [math]::Round($drive.Free / 1Gb, 2)
               $name = $drive.Name
               if ($Size -gt $free) {
                  Write-Output "${free}GB of space on $name."
                  $errors += 1
               }
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

      Write-Output "All disk space checked and clear."
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
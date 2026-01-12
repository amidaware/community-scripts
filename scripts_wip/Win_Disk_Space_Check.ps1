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
   Updated: Owen Conti 2025-12-12
#>

Param(
   [Parameter(Mandatory = $false)]
   [int]#The minimum amount of GB that should be available
   $Size = 25,

   [Parameter(Mandatory = $false)]
   [switch]#Switches the Size to be a percentage instead of GB
   $Percent
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

         "$($drive.Name) $available $label space remaining."

         if ($Size -gt $available) {
            $errors += 1
         }
      }
   }

   Catch {
      "ERROR: ${$_.Exception}"
      Exit 1
   }
}

End {
   if ($errors -gt 0) { Exit 1 }
   Exit 0
}

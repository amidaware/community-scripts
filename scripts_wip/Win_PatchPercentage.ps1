<#
.Synopsis
    Gets the patch percentage of the Windows computer.
.EXAMPLE
    Win_PatchPercentage
.NOTES
   Version: 1
   Author: redanthrax
   Creation Date: 2022-06-06
#>

function Win_PatchPercentage {
    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    Process {
        Try {
            $updates = (New-Object -c Microsoft.Update.Session).CreateUpdateSearcher()
            $installed = $updates.Search("IsInstalled=1").Updates.Count
            $missing = $updates.Search("IsInstalled=0").Updates.Count
            $complete = ($installed / ($installed + $missing)).ToString("P")
            Write-Output $complete
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        #Script cleanup and final checks here
        #Check for last errors and exit
        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_PatchPercentage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
Win_PatchPercentage
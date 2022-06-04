<#
.Synopsis
    Checks Hyper-V Replication Status
.DESCRIPTION
    This script uses the Measure-VMReplication module to check replication status.
.EXAMPLE
    Win_HyperVReplication_Status
.INSTRUCTIONS
    
.NOTES
   Version: 1
   Author: redanthrax
   Creation Date: 2022-06-03
#>

function Win_HyperVReplication_Status {
    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if(-Not(Get-Command Measure-VMReplication -ErrorAction SilentlyContinue)) {
            Write-Output "Measure-VMReplication command not available."
            Exit 0
        }
    }

    Process {
        Try {
            Measure-VMReplication | Foreach-Object {
                if($_.Health -ne 'Normal' -or $_.LReplTime -lt (Get-Date).AddDays(-2)) {
                    throw "$($_.Name) health $($_.Health) last replicated $(if($_.LReplTime){$_.LReplTime } else { 'Never' }): State $($_.State)"
                }
            }

            Write-Output "Replication health normal."
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        if($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_HyperVReplication_Status' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
Win_HyperVReplication_Status
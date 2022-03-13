<#
      .SYNOPSIS
        Pull Tactical RMM and Mesh Log File contents
      .DESCRIPTION
        Will pull last 50 lines of log. Can pull more/less lines if desired
      .PARAMETER Lines
        Provide number of lines desired
      .EXAMPLE
        -Lines 100
      .NOTES
        2/2022 v1 Initial release by @silversword411
  #>

  param (
    [Int] $Lines
)

if (!$Lines) {
    # Write-output "Lines = $Lines"
    $Lines = "50"
}

$logcontents = Get-Content -LiteralPath "C:\Program Files\TacticalAgent\agent.log" -Tail $Lines
Write-Output "TRMM Agent Logs"
Write-Output $logcontents

$mlogcontents = Get-Content -LiteralPath "C:\Program Files\Mesh Agent\MeshAgent.log" -Tail $Lines
Write-Output "Mesh Agent Logs"
Write-Output $mlogcontents
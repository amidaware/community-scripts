<#
      .SYNOPSIS
      This will list the 10 largest files on your chosen drive 
      .PARAMETER Drive
      The assumed drive letter is C:\ to scan another drive use -Drive D:\
      .EXAMPLE
      -Drive D:\
      .NOTE
      TODO Needs parameters for number of files
  #>

param (
    [string] $Drive
)

if ($Drive -Match ":\") {
    Write-Output "Scanning $Drive for 10 largest files"
    get-ChildItem $Drive -recurse -erroraction silentlycontinue | sort length -descending | select -first 10
}

else {
    Write-Output "Scanning C:\ for 10 largest files"
    get-ChildItem C:\ -recurse -erroraction silentlycontinue | sort length -descending | select -first 10
}

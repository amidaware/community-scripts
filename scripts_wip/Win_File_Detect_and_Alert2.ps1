<#
.Synopsis
   Detect if object exists and gives error
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>


$test = 'Get-ChildItem c:\temp | Where-Object {($_.PSIsContainer -ne $true) -and ($_.name -like ' * .exe')}'





$vDIR = 'C:\temp'
$vFILE = '*.exe'

$proc = @(Get-ChildItem $vDIR -Recurse -Include $vFile)
If ($proc.count -gt 0) {
   ForEach ($item in $proc) {
      Write-Output 'no .exe in download folder'
   }
   Else {
      Write-Output ".exe exists in download folder"
   }
}

$targetDir = "$($env:USERPROFILE)\Downloads\"
Write-Output "targetDir is $targetDir"
# $targetDir = "c:\temp"
$test = get-Item $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-100)) }
Write-Output $test
$pattern = "*.exe"
If ((get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-100)) }) -eq $true ) {
    
   Write-Output ".exe exists in download folder"
   exit 0

}
Else {

   Write-Output 'no .exe in download folder'
   exit 1
} 

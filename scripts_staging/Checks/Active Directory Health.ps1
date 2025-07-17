<#
.SYNOPSIS
    This script performs Active Directory (AD) diagnostics and compares Group Policy Object (GPO) version numbers between Sysvol and Active Directory.

.DESCRIPTION
    The script performs a series of Active Directory tests using DCDIAG, checks for discrepancies in GPO versions between Sysvol and AD, and outputs the results. 
    It also checks if the Active Directory Domain Services (AD-DS) feature is installed on the system before performing these tests.
    If any test fails, the exit code is incremented. The script provides detailed output for each test and comparison, indicating success or failure.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.CHANGELOG
    17.07.25 SAN Big cleanup of bug fixes for the dcdiag function, fixes of error codes, output in stderr of all errors for readability

.TODO
    Do a breakdown at the top of the output for easy read with ok/ko returns from functions
    
#>

# Initialize exit code
$global:exitCode = 0

# Function to perform Active Directory tests
function CheckAD {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Tests,

        [Parameter()]
        [hashtable]$SuccessPatterns = @{
            'en' = @('passed test')
            'fr' = @('a réussi', 'a reussi', 'a russi', 'ussi')
        },

        [Parameter()]
        [int]$MinimumMatches = 2
    )

    $DebugMode = $false
    $global:exitCode = 0

    # Combine all success patterns from all languages into a single list
    $allPatterns = @()
    foreach ($lang in $SuccessPatterns.Keys) {
        $allPatterns += $SuccessPatterns[$lang]
    }

    if ($DebugMode) {
        Write-Host "`n[DEBUG] Loaded Success Patterns:"
        foreach ($p in $allPatterns) {
            Write-Host " - $p"
        }
        Write-Host ""
    }

    $results = @{}

    foreach ($test in $Tests) {
        Write-Host "`nRunning DCDIAG test: $test"

        # Start dcdiag process and redirect output
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = "dcdiag.exe"
        $startInfo.Arguments = "/test:$test"
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $process.Start() | Out-Null
        $stream = $process.StandardOutput.BaseStream
        $memoryStream = New-Object System.IO.MemoryStream
        $buffer = New-Object byte[] 4096
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $memoryStream.Write($buffer, 0, $read)
        }
        $process.WaitForExit()

        $bytes = $memoryStream.ToArray()
        $output = [System.Text.Encoding]::GetEncoding(1252).GetString($bytes)

        if ($DebugMode) {
            $preview = if ($output.Length -gt 800) { $output.Substring(0,800) + "`n..." } else { $output }
            Write-Host "[DEBUG] DCDIAG Output Preview:"
            Write-Host $preview
            Write-Host ""
        }

        $matchCount = 0
        foreach ($pattern in $allPatterns) {
            $count = ([regex]::Matches($output, [regex]::Escape($pattern))).Count
            $matchCount += $count

            if ($DebugMode) {
                Write-Host "[DEBUG] Pattern '$pattern' matched $count time(s)."
            }
        }

        if ($DebugMode) {
            Write-Host "[DEBUG] Total success match count: $matchCount`n"
        }

        if ($matchCount -ge $MinimumMatches) {
            $results[$test] = "OK"
        } else {
            $results[$test] = "Failed!"
            Write-Error "$results[$test] = Failed!"
            $global:exitCode++
        }

        Write-Host "DCDIAG Test: $test Result: $($results[$test])"
    }

    return $results
}

# Function to compare GPO version numbers
function Compare-GPOVersions {
    [CmdletBinding()]
    param ()

    process {
        Import-Module GroupPolicy

        Get-GPO -All | ForEach-Object {
            # Retrieve GPO information (GUID and Name)
            $GPOId = $_.Id
            $GPOName = $_.DisplayName

            # Version GPO User
            $NumUserSysvol = (Get-Gpo -Guid $GPOId).User.SysvolVersion
            $NumUserAD = (Get-Gpo -Guid $GPOId).User.DSVersion

            # Version GPO Machine
            $NumComputerSysvol = (Get-Gpo -Guid $GPOId).Computer.SysvolVersion
            $NumComputerAD = (Get-Gpo -Guid $GPOId).Computer.DSVersion

            # USER - Compare version numbers
            if ($NumUserSysvol -ne $NumUserAD) {
                Write-Host "$GPOName ($GPOId) : USER Versions différentes (Sysvol : $NumUserSysvol | AD : $NumUserAD)" 
                Write-Error "$GPOName ($GPOId) : USER Versions différentes (Sysvol : $NumUserSysvol | AD : $NumUserAD)"
                $global:exitCode++
            } else {
                Write-Host "$GPOName : USER Versions identiques" 
            }

            # COMPUTER - Compare version numbers
            if ($NumComputerSysvol -ne $NumComputerAD) {Health
                Write-Host "$GPOName ($GPOId) : COMPUTER Versions différentes (Sysvol : $NumComputerSysvol | AD : $NumComputerAD)" 
                Write-Error "$GPOName ($GPOId) : COMPUTER Versions différentes (Sysvol : $NumComputerSysvol | AD : $NumComputerAD)" 
                $global:exitCode++
            } else {
                Write-Host "$GPOName : COMPUTER Versions identiques" 
            }
        }
        Write-Host "GPO USER/COMPUTER Version OK"
    }
}

# Function to check if the Recycle Bin in enabled
function Check-ADRecycleBin {
    $recycleFeatures = Get-ADOptionalFeature -Filter {name -like "recycle bin feature"}

    foreach ($feature in $recycleFeatures) {
        if ($null -ne $feature.EnabledScopes) {
            Write-Host "OK: Recycle Bin enabled"
        } else {
            Write-Host "KO: Recycle Bin disabled"
            Write-Error "KO: Recycle Bin disabled"
            $global:exitCode++ 
        }
    }
}

# Check if Active Directory Domain Services feature is installed
try {
    $adFeature = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction Stop

    if ($adFeature.InstallState -eq "Installed") {
        
        # function with the AD tests
        $tests = ("Advertising", "FrsSysVol", "MachineAccount", "Replications", "RidManager", "Services", "FsmoCheck", "SysVolCheck")
        Write-Host "DCDIAG tests: $tests"
        $testResults = CheckAD -Tests $tests
        $failedTests = $testResults.GetEnumerator() | Where-Object { $_.Value -eq "Failed!" }
        if ($failedTests) {
            Write-Error "Some Active Directory tests failed."
        } else {
            Write-Host "All Active Directory tests passed successfully."
        }
        Write-Host ""

        # function to compare GPO versions
        Write-Host "GPO Versions checks"
        Compare-GPOVersions
        Write-Host ""

        # function to check the Recycle Bin
        Write-Host "Recycle Bin checks"
        Check-ADRecycleBin
        Write-Host ""

    } else {
        Write-Host "Active Directory Domain Services feature is not installed or not in the 'Installed' state."
        exit
    }
} catch {
    Write-Error "Failed to retrieve information about Active Directory Domain Services feature: $_"
    $global:exitCode++
}

$host.SetShouldExit($global:exitCode)
exit $global:exitCode
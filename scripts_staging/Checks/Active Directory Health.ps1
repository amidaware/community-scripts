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
    
#>

# Initialize exit code
$exitCode = 0

# Function to perform Active Directory tests
function CheckAD {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$Tests
    )

    process {
        $results = @{}

        foreach ($test in $Tests) {
            $output = dcdiag /test:$test

            if ($output -notmatch "chou") {
                $results[$test] = "OK"
            } else {
                $results[$test] = "Failed!"
                $global:exitCode++
            }

            # Output individual test result
            Write-Host "DCDIAG Test: $test Result: $($results[$test])"
        }

        $results
    }
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
                Write-Host "$GPOName ($GPOId) : USER Versions différentes (Sysvol : $NumUserSysvol | AD : $NumUserAD)" -ForegroundColor Red
                $global:exitCode++
            } else {
                Write-Host "$GPOName : USER Versions identiques" -ForegroundColor Green
            }

            # COMPUTER - Compare version numbers
            if ($NumComputerSysvol -ne $NumComputerAD) {
                Write-Host "$GPOName ($GPOId) : COMPUTER Versions différentes (Sysvol : $NumComputerSysvol | AD : $NumComputerAD)" -ForegroundColor Red
                $global:exitCode++
            } else {
                Write-Host "$GPOName : COMPUTER Versions identiques" -ForegroundColor Green
            }
        }
        Write-Host "GPO USER/COMPUTER Version OK" -ForegroundColor Green
    }
}

# Check if Active Directory Domain Services feature is installed
try {
    $adFeature = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction Stop

    if ($adFeature.InstallState -eq "Installed") {
        # Specify your AD tests
        $tests = ("Advertising", "FrsSysVol", "MachineAccount", "Replications", "RidManager", "Services", "FsmoCheck", "SysVolCheck")
        # Call the function with the AD tests
        Write-Host "DCDIAG"
        $testResults = CheckAD -Tests $tests

        $failedTests = $testResults.GetEnumerator() | Where-Object { $_.Value -eq "Failed!" }

        if ($failedTests) {
            Write-Error "Some Active Directory tests failed."
            $failedTests | ForEach-Object { Write-Error "$($_.Key) test failed." }
            $global:exitCode += $failedTests.Count
        } else {
            Write-Host "All Active Directory tests passed successfully."
        }
        Write-Host ""
        Write-Host "GPO Versions checks"
        # Call the function to compare GPO versions
        Compare-GPOVersions
    } else {
        Write-Host "Active Directory Domain Services feature is not installed or not in the 'Installed' state."
        exit
    }
} catch {
    Write-Error "Failed to retrieve information about Active Directory Domain Services feature: $_"
    $global:exitCode++
}

exit $exitCode
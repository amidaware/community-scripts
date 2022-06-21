<#
    .SYNOPSIS
    Checks Eset AV Status

    .DESCRIPTION
    Uses ermm.exe and checks the generated json file for problems.
    Don't forget to whitelist powershell for ermm.exe execution (see Eset Documentation)

    .INPUTS
    None

    .OUTPUTS
    Errorlevel: 0 if everything is OK. 1 for security problem; 2+ for other problems.

    .EXAMPLE
    .\Win_Eset_Check_AV_Status.ps1 

    .NOTES
        Changelog
        v 0.1.0 initial version

    .LINK
        https://github.com/zetaworx/tacticalrmm-scripts
#>

[CmdletBinding()]
param()

$RegistryEsetPath = "HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\Info"

Write-Verbose "Checking Key $RegistryEsetPath for Installation Directory"
Try { 
    $EsetErmmPath = Get-ItemPropertyValue $RegistryEsetPath -Name "InstallDir" -ErrorAction Stop
}
catch { 
    Write-Host "ERROR: registry key not found. Eset Software not installed?"
    exit 2
}

$EsetErmmExe = $EsetErmmPath + "ermm.exe"

Write-Verbose "Checking for ermm.exe binary"
Switch ( Test-Path -Path $EsetErmmExe -PathType Leaf ) {
    $True { 
        Write-Verbose "File found: $EsetErmmExe"
    }
    $False { 
        Write-Host "ERROR: File not found: $EsetErmmExe"
        exit 2
    }
}

Write-Verbose "Calling $EsetErmmExe to get JSON output"
try {
    $EsetErmmOutput = & $EsetErmmExe "get" "protection-status" | ConvertFrom-Json
}
catch {
    $Exception = $_.Exception
    Write-Host "ERROR: problem with json output. $($Exception)"
    Exit 2
}

Write-Verbose "Output: $($EsetErmmOutput)"
Write-Verbose "Description: $($EsetErmmOutput.result.description)"
Write-Verbose "Status: $($EsetErmmOutput.result.status)"
Write-Verbose "Errortext: $($EsetErmmOutput.error.text)"

Write-Verbose "Checking JSON output"
If ( $EsetErmmOutput.error.text -ne $null ) {
    Write-Host "ESET: something went wrong. - $($EsetErmmOutput.error.text)"
    Exit 2
}
If ( $EsetErmmOutput.result.status -eq "0" ) {
    Write-Host "ESET: Protection Status OK - $($EsetErmmOutput.result.description)"
    Exit 0
} else {
    Write-Host "ESET: Protection Status WARNING - $($EsetErmmOutput.result.description)"
    Exit 1
}

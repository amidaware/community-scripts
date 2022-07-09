<#
.SYNOPSIS
.DESCRIPTION
.EXAMPLE
.INSTRUCTIONS
.NOTES
#>

$uninstallBase64 = "<snip> base64 that created zip with crc error, unable to validate file contents removed"

function Win_Labtech_Uninstall {
    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" `
            | Out-Null }
    }

    Process {
        Try {
            $bytes = [Convert]::FromBase64String($uninstallBase64)
            [IO.File]::WriteAllBytes("C:\packages$random\uninstall.zip", $bytes)
            Expand-Archive "C:\packages$random\uninstall.zip" -DestinationPath "C:\packages$random\uninstall"
            Write-Output "Starting uninstall process."
            $process = Start-Process -NoNewWindow -FilePath "C:\packages$random\uninstall\Agent_Uninstall.exe" `
                -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if($timedOut) {
                $process | kill
                Write-Output "Uninstall timed out after 300 seconds."
                Exit 1
            }
            elseif($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code."
                Exit 1
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
            Exit 1
        }
    }

    End {
        Write-Output "Waiting for uninstall to start up."
        Start-Sleep -Seconds 10
        while(Get-Process "Uninstall" -ErrorAction SilentlyContinue) {
            Write-Output "Waiting for uninstall to finish..."
            Start-Sleep -Seconds 5
        }

        Write-Output "Cleaning up."
        Start-Sleep -Seconds 5
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        Exit 0 
    }
}

if(-not(Get-Command "Win_Labtech_Uninstall" -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

Win_Labtech_Uninstall
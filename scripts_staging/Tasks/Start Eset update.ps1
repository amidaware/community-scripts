<#
.SYNOPSIS
    This script attempts to execute the ESET Security update process, retrying if the process fails due to specific errors or no output being returned.

.DESCRIPTION
    The script runs the ESET Security update command using `ermm.exe`, capturing the output in a temporary file. 
    If the process exits with a non-zero code or produces invalid output, the script retries the operation up to a maximum retry count. 

.NOTES
    Author: SAN
    Date: 2024-12-11
    #public

.CHANGELOG

.TODO

#>

$retryCount = 10
$retryDelaySeconds = 5

for ($i = 0; $i -lt $retryCount; $i++) {
    try {
        $outputFile = [System.IO.Path]::GetTempFileName()
        $process = Start-Process -FilePath "C:\Program Files\ESET\ESET Security\ermm.exe" -ArgumentList "start update" -NoNewWindow -RedirectStandardOutput $outputFile -PassThru -Wait

        if ($process.ExitCode -ne 0) {
            Write-Host "Error: The process exited with code $($process.ExitCode)."
            exit 1
        }

        $output = Get-Content -Path $outputFile -Raw

        if ($null -eq $output) {
            Write-Host "Error: No output received from the process."
            exit 1
        }

        if ($output -notmatch '"error":null') {
            Write-Host "Error: 'error':null not found in output."
            Write-Host "Output: $output"
            # Continue to retry
            Write-Host "Retrying in $retryDelaySeconds seconds..."
            Start-Sleep -Seconds $retryDelaySeconds
            continue
        }

        # If execution reaches here, the operation was successful
        Write-Host "Update process completed successfully."
        break
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Host "Attempt $($i+1): An error occurred: $errorMessage"
        if ($errorMessage -match "Cannot process request because the process" -or $errorMessage -match "Impossible de traiter la demande, car le processus") {
            Write-Host "Retrying in $retryDelaySeconds seconds..."
            Start-Sleep -Seconds $retryDelaySeconds
            continue
        }
        else {
            exit 1
        }
    } finally {
        if (Test-Path $outputFile) {
            Write-Host "Output: $output"
            Remove-Item $outputFile -Force
        }
    }
}

if ($i -eq $retryCount) {
    Write-Host "Error: Maximum retry attempts reached. Update process failed."
    exit 1
}
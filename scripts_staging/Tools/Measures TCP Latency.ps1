<#
.SYNOPSIS
    Measures TCP connection latency to a specified host and port with optional detailed output.

.DESCRIPTION
    This function performs multiple TCP connection attempts to a target host and port.
    It includes an initial "warm-up" attempt to avoid DNS resolution or cold TCP stack, then measures latency
    for the specified number of connection attempts.
    This tool is intended for cases where ICMP is not available.

.PARAMETER TargetHost
    The hostname or IP address of the target to test.

.PARAMETER Port
    The TCP port to connect to on the target host. Default is 80.

.PARAMETER Count
    The number of test attempts to perform (excluding the first warm-up). Default is 5.

.PARAMETER Timeout
    The maximum time (in milliseconds) to wait for each connection attempt. Default is 3000 ms.

.PARAMETER Silent
    If set, disables output to the console and instead returns a list of latencies.

.PARAMETER OutputMode
    Optional output format. Can be 'None', 'Json', or 'Csv'.

.EXAMPLE
    -TargetHost "example.com" -Port 443 -Count 5
    -TargetHost "192.168.1.1" -Port 22 -Count 3 -Silent -OutputMode Json

.NOTES
    Author: SAN
    Date: 15.04.25
    #public

#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetHost,

    [ValidateRange(1, 65535)]
    [int]$Port = 80,

    [ValidateRange(1, 1000)]
    [int]$Count = 5,

    [ValidateRange(1, 60000)]
    [int]$Timeout = 3000,

    [switch]$Silent,

    [ValidateSet("None", "Json", "Csv")]
    [string]$OutputMode = "None"
)

function Test-TcpLatency {
    param (
        [string]$TargetHost,
        [int]$Port,
        [int]$Count,
        [int]$Timeout,
        [switch]$Silent,
        [string]$OutputMode
    )

    $latencies = @()
    $successes = 0
    $failures = 0

    for ($i = 0; $i -le $Count; $i++) {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $resultText = ""

        try {
            $asyncResult = $tcpClient.BeginConnect($TargetHost, $Port, $null, $null)
            $waitHandle = $asyncResult.AsyncWaitHandle

            if ($waitHandle.WaitOne($Timeout, $false)) {
                $tcpClient.EndConnect($asyncResult)
                $stopwatch.Stop()
                $latency = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 3)

                if ($i -gt 0) {
                    $latencies += $latency
                    $successes++
                    $resultText = "Attempt $i : Connected to $TargetHost : $Port in ${latency}ms"
                    if (-not $Silent) {
                        Write-Host $resultText
                    }
                } else {
                    if (-not $Silent) {
                        Write-Host "Warm-up ignored (${latency}ms)"
                    }
                }
            } else {
                $stopwatch.Stop()
                if ($i -gt 0) {
                    $failures++
                    $resultText = "Attempt $i : Timeout after $Timeout ms"
                    if (-not $Silent) {
                        Write-Host $resultText
                    }
                } else {
                    if (-not $Silent) {
                        Write-Host "Warm-up attempt timed out (ignored)"
                    }
                }
            }
        } catch {
            if ($i -gt 0) {
                $failures++
                $resultText = "Attempt $i : Connection error: $_"
                if (-not $Silent) {
                    Write-Host $resultText
                }
            } else {
                if (-not $Silent) {
                    Write-Host "Warm-up attempt failed (ignored): $_"
                }
            }
        } finally {
            $tcpClient.Close()
            $waitHandle.Close()
        }

        Start-Sleep -Seconds 1
    }

    if (-not $Silent) {
        Write-Host "`nSummary for $TargetHost : $Port"
        Write-Host ("  Successful attempts: {0,3}" -f $successes)
        Write-Host ("  Failed attempts:     {0,3}" -f $failures)
        if ($latencies.Count -gt 0) {
            $avg = [math]::Round(($latencies | Measure-Object -Average).Average, 3)
            $min = ($latencies | Measure-Object -Minimum).Minimum
            $max = ($latencies | Measure-Object -Maximum).Maximum
            Write-Host ("  Avg latency:           {0,3} ms" -f $avg)
            Write-Host ("  Min latency:           {0,3} ms" -f $min)
            Write-Host ("  Max latency:           {0,3} ms" -f $max)
        } else {
            Write-Host "  No successful connections to calculate latency."
        }
    }

    switch ($OutputMode) {
        "Json" { $latencies | ConvertTo-Json -Depth 1 }
        "Csv" {
            $latencies | ForEach-Object {
                [PSCustomObject]@{ Latency = $_ }
            } | ConvertTo-Csv -NoTypeInformation
        }
        default {
            if ($Silent) {
                return $latencies
            }
        }
    }
}

Test-TcpLatency -TargetHost $TargetHost -Port $Port -Count $Count -Timeout $Timeout -Silent:$Silent -OutputMode $OutputMode

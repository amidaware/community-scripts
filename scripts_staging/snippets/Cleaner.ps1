#public
<# 
.SYNOPSIS
   Automate cleaning up the C:\ drive with low disk space warning.

.DESCRIPTION
   Cleans the C: drive's Windows Temporary files, Windows SoftwareDistribution folder, 
   the local users Temporary folder, IIS logs(if applicable) and empties the recycle bin. 
   All deleted files will go into a log transcript in $env:TEMP. By default this 
   script leaves files that are newer than 7 days old however this variable can be edited.


.NOTES
   This script will typically clean up anywhere from 1GB up to 15GB of space from a C: drive.

.CHANGELOG
    Changed to 25 day of IIS logs
    19.11.24 SAN Added adobe updates folder to cleanup
    19.11.24 SAN removed colors
    19.11.24 SAN added cleanup of search index
    
.TODO
    Full code refactoring, get everything out of function, remove logging, streamline opperation 

#>
Function Start-Cleanup {


## Allows the use of -WhatIf
[CmdletBinding(SupportsShouldProcess=$True)]

param(
    ## Delete data older then $daystodelete
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)]
    $DaysToDelete = 7,

    ## LogFile path for the transcript to be written to
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)]
    $LogFile = ("$env:TEMP\" + (get-date -format "MM-d-yy-HH-mm") + '.log'),

    ## All verbose outputs will get logged in the transcript($logFile)
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=2)]
    $VerbosePreference = "Continue",

    ## All errors should be withheld from the console
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=3)]
    $ErrorActionPreference = "SilentlyContinue"
)

    ## Begin the timer
    $Starters = (Get-Date)
    
    ## Check $VerbosePreference variable, and turns -Verbose on
    Function global:Write-Verbose ( [string]$Message ) {
        if ( $VerbosePreference -ne 'SilentlyContinue' ) {
            Write-Host "$Message"
        }
    }

    ## Tests if the log file already exists and renames the old file if it does exist
    if(Test-Path $LogFile){
        ## Renames the log to be .old
        Rename-Item $LogFile $LogFile.old -Verbose -Force
    } else {
        ## Starts a transcript in C:\temp so you can see which files were deleted
        Write-Host (Start-Transcript -Path $LogFile)
    }

    ## Writes a verbose output to the screen for user information
    Write-Host "Retriving current disk percent free for comparison once the script has completed."
    Write-Host "[DONE]"

    ## Gathers the amount of disk space used before running the script
    $Before = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
    @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
    @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
    @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
    @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } } |
        Format-Table -AutoSize |
        Out-String

    ## Stops the windows update service so that c:\windows\softwaredistribution can be cleaned up
    Get-Service -Name wuauserv | Stop-Service -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Verbose

    # Sets the SCCM cache size to 1 GB if it exists.
    if ((Get-WmiObject -namespace root\ccm\SoftMgmtAgent -class CacheConfig) -ne "$null"){
        # if data is returned and sccm cache is configured it will shrink the size to 1024MB.
        $cache = Get-WmiObject -namespace root\ccm\SoftMgmtAgent -class CacheConfig
        $Cache.size = 1024 | Out-Null
        $Cache.Put() | Out-Null
        Restart-Service ccmexec -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }

    ## Compaction of Windows.edb
    # Check if the Windows.edb file exists
    $windowsEdbPath = "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Applications\Windows\Windows.edb"
    if (Test-Path $windowsEdbPath) {

        # Disable the Windows Search service
        Write-Host "Disabling the Windows Search service..."
        Set-Service -Name wsearch -StartupType Disabled

        # Stop the Windows Search service
        Write-Host "Stopping the Windows Search service..."
        Stop-Service -Name wsearch -Force
        Write-Host "Windows Search service stopped."

        # Perform offline compaction of the Windows.edb file
        Write-Host "Performing offline compaction of the Windows.edb file..."
        Start-Process -FilePath "esentutl.exe" -ArgumentList "/d `"$windowsEdbPath`"" -NoNewWindow -Wait
        Write-Host "Compaction completed."

        # Set the Windows Search service to manual start
        Write-Host "Setting the Windows Search service to manual start..."
        Set-Service -Name wsearch -StartupType Manual

        # Start the Windows Search service
        Write-Host "Starting the Windows Search service..."
        Start-Service -Name wsearch
        Write-Host "Windows Search service started."

    } else {
        Write-Host "Windows.edb file not found, skipping all actions."
    }

    ## Delete old adobe updates
    Get-ChildItem "C:\ProgramData\Adobe\ARM\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -ErrorAction SilentlyContinue -Verbose
    Write-Host "The Contents of Adobe ARM have been removed successfully!"
    Write-Host "[DONE]"

    ## Deletes the contents of the Windows Temp folder.
    Get-ChildItem "C:\Windows\Temp\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
        Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete)) } | Remove-Item -force -recurse -ErrorAction SilentlyContinue -Verbose
    Write-host "The Contents of Windows Temp have been removed successfully!"
    Write-Host "[DONE]"

    ## Deletes the contents of Windows Software Distribution.
    Get-ChildItem "C:\Windows\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -recurse -ErrorAction SilentlyContinue -Verbose
    Write-Host "The Contents of Windows SoftwareDistribution have been removed successfully!"
    Write-Host "[DONE]"

    ## Deletes all files and folders in user's Temp folder older then $DaysToDelete
    Get-ChildItem "C:\users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete))} |
        Remove-Item -force -recurse -ErrorAction SilentlyContinue -Verbose
    Write-Host "The contents of `$env:TEMP have been removed successfully!"
    Write-Host "[DONE]"

        ## Deletes all files and folders in CSBack folder older then $DaysToDelete
    Get-ChildItem "C:\csback\*" -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete))} |
        Remove-Item -force -recurse -ErrorAction SilentlyContinue -Verbose
    Write-Host "The contents of csback have been removed successfully!"
    Write-Host "[DONE]"

    ## Removes all files and folders in user's Temporary Internet Files older then $DaysToDelete
    Get-ChildItem "C:\users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" `
        -Recurse -Force -Verbose -ErrorAction SilentlyContinue |
        Where-Object {($_.CreationTime -lt $(Get-Date).AddDays( - $DaysToDelete))} |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -Verbose
    Write-Host "All Temporary Internet Files have been removed successfully!"
    Write-Host "[DONE]"

    ## Removes *.log from C:\windows\CBS
    if(Test-Path C:\Windows\logs\CBS\){
    Get-ChildItem "C:\Windows\logs\CBS\*.log" -Recurse -Force -ErrorAction SilentlyContinue |
        remove-item -force -recurse -ErrorAction SilentlyContinue -Verbose
    Write-Host "All CBS logs have been removed successfully!"
    Write-Host "[DONE]"
    } else {
        Write-Host "C:\inetpub\logs\LogFiles\ does not exist, there is nothing to cleanup."
        Write-Host "[WARNING]"
    }

    ## Cleans IIS Logs older then $DaysToDelete
    if (Test-Path C:\inetpub\logs\LogFiles\) {
        Get-ChildItem "C:\inetpub\logs\LogFiles\*" -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-25)) } | Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue
        Write-Host "All IIS Logfiles over $DaysToDelete days old have been removed Successfully!"
        Write-Host "[DONE]"
    }
    else {
        Write-Host "C:\Windows\logs\CBS\ does not exist, there is nothing to cleanup."
        Write-Host "[WARNING]"
    }

    ## Removes C:\Config.Msi
    if (test-path C:\Config.Msi){
        remove-item -Path C:\Config.Msi -force -recurse -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "C:\Config.Msi does not exist, there is nothing to cleanup."
        Write-Host "[WARNING]"
    }

    ## Removes c:\Intel
    if (test-path c:\Intel){
        remove-item -Path c:\Intel -force -recurse -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "c:\Intel does not exist, there is nothing to cleanup."
        Write-Host "[WARNING]"
    }

    ## Removes c:\PerfLogs
    if (test-path c:\PerfLogs){
        remove-item -Path c:\PerfLogs -force -recurse -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "c:\PerfLogs does not exist, there is nothing to cleanup."
        Write-Host "[WARNING]"
    }

    ## Removes $env:windir\memory.dmp
    if (test-path $env:windir\memory.dmp){
        remove-item $env:windir\memory.dmp -force -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "C:\Windows\memory.dmp does not exist, there is nothing to cleanup."
        Write-Host "[WARNING]"
    }

    ## Removes rouge folders
    Write-host "Deleting Rouge folders"
    Write-Host "[DONE]"

    ## Removes Windows Error Reporting files
    if (test-path C:\ProgramData\Microsoft\Windows\WER){
        Get-ChildItem -Path C:\ProgramData\Microsoft\Windows\WER -Recurse | Remove-Item -force -recurse -Verbose -ErrorAction SilentlyContinue
            Write-host "Deleting Windows Error Reporting files"
            Write-Host "[DONE]"
        } else {
            Write-Host "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup."
            Write-Host "[WARNING]"
    }

    ## Removes System and User Temp Files - lots of access denied will occur.
    ## Cleans up c:\windows\temp
    if (Test-Path $env:windir\Temp\) {
        Remove-Item -Path "$env:windir\Temp\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Windows\Temp does not exist, there is nothing to cleanup."
            Write-Host "[WARNING]"
    }

    ## Cleans up minidump
    if (Test-Path $env:windir\minidump\) {
        Remove-Item -Path "$env:windir\minidump\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "$env:windir\minidump\ does not exist, there is nothing to cleanup."
            Write-Host "[WARNING]"
    }

    ## Cleans up prefetch
    if (Test-Path $env:windir\Prefetch\) {
        Remove-Item -Path "$env:windir\Prefetch\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "$env:windir\Prefetch\ does not exist, there is nothing to cleanup."
            Write-Host "[WARNING]"
    }

    ## Cleans up each user's temp folder
    if (Test-Path "C:\Users\*\AppData\Local\Temp\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Temp\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Temp\ does not exist, there is nothing to cleanup."
            Write-Host "[WARNING]"
    }

    ## Cleans up all user's Windows error reporting
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\WER\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\ProgramData\Microsoft\Windows\WER does not exist, there is nothing to cleanup."
            Write-Host "[WARNING]"
    }

    ## Cleans up user's temporary internet files
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\ does not exist."
            Write-Host "[WARNING]"
    }

    ## Cleans up Internet Explorer cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\ does not exist."
            Write-Host "[WARNING]"
    }

    ## Cleans up Internet Explorer cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\ does not exist."
            Write-Host "[WARNING]"
    }

    ## Cleans up Internet Explorer download history
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\ does not exist."
            Write-Host "[WARNING]"
    }

    ## Cleans up Internet Cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\ does not exist."
            Write-Host "[WARNING]"
    }

    ## Cleans up Internet Cookies
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\ does not exist."
            Write-Host "[WARNING]"
    }

    ## Cleans up terminal server cache
    if (Test-Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\") {
        Remove-Item -Path "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\*" -Force -Recurse -Verbose -ErrorAction SilentlyContinue
    } else {
            Write-Host "C:\Users\*\AppData\Local\Microsoft\Terminal Server Client\Cache\ does not exist."
            Write-Host "[WARNING]"
    }

    Write-host "Removing System and User Temp Files"
    Write-Host "[DONE]"

    ## Removes the hidden recycle bin.
    if (Test-path 'C:\$Recycle.Bin'){
        Remove-Item 'C:\$Recycle.Bin' -Recurse -Force -Verbose -ErrorAction SilentlyContinue
    } else {
        Write-Host "C:\`$Recycle.Bin does not exist, there is nothing to cleanup."
        Write-Host "[WARNING]"
    }

    ## Turns errors back on
    $ErrorActionPreference = "Continue"

    ## Checks the version of PowerShell
    ## If PowerShell version 4 or below is installed the following will process
    if ($PSVersionTable.PSVersion.Major -le 4) {

        ## Empties the recycle bin, the desktop recycle bin
        $Recycler = (New-Object -ComObject Shell.Application).NameSpace(0xa)
        $Recycler.items() | ForEach-Object { 
            ## If PowerShell version 4 or below is installed the following will process
            Remove-Item -Include $_.path -Force -Recurse -Verbose
            Write-Host "The recycling bin has been cleaned up successfully!"
            Write-Host "[DONE]"
        }
    } elseif ($PSVersionTable.PSVersion.Major -ge 5) {
         ## If PowerShell version 5 is running on the machine the following will process
         Clear-RecycleBin -DriveLetter C:\ -Force -Verbose
         Write-Host "The recycling bin has been cleaned up successfully!"
         Write-Host "[DONE]"
    }

    ## Starts cleanmgr.exe
    # Function to add the registry keys
    function Add-RegistryKeys {
        # Define the base registry key path
        $baseKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\"

        # Get all subkeys under the base key
        $subKeys = Get-ChildItem -Path $baseKey -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -ne "StateFlags0001" }

        # Loop through each subkey and create/update the DWORD value
        foreach ($subKey in $subKeys) {
            $keyPath = Join-Path -Path $baseKey -ChildPath $subKey.PSChildName
            $valueName = "StateFlags0001"
            $value = 2

            # Check if the value already exists, if not create it
            if (-not (Test-Path -Path "$keyPath\$valueName")) {
                New-ItemProperty -Path $keyPath -Name $valueName -Value $value -PropertyType DWORD -Force | Out-Null
            } else {
                # Update the existing value
                Set-ItemProperty -Path $keyPath -Name $valueName -Value $value
            }
        }

        Write-Host "StateFlags0001 DWORD value created/updated in all subkeys under $baseKey"
    }



    # Add registry keys
    Add-RegistryKeys
    # Run Disk Cleanup with sagerun1
    Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait


    ## gathers disk usage after running the cleanup cmdlets.
    $After = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" } | Select-Object SystemName,
    @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
    @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
    @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
    @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } } |
        Format-Table -AutoSize | Out-String

    ## Restarts wuauserv
    Get-Service -Name wuauserv | Start-Service -ErrorAction SilentlyContinue

    ## Stop timer
    $Enders = (Get-Date)

    ## Calculate amount of seconds your code takes to complete.
    Write-Verbose "Elapsed Time: $(($Enders - $Starters).totalseconds) seconds

"
    ## Sends hostname to the console for ticketing purposes.
    Write-Host (Hostname)

    ## Sends the date and time to the console for ticketing purposes.
    Write-Host (Get-Date | Select-Object -ExpandProperty DateTime)

    ## Sends the disk usage before running the cleanup script to the console for ticketing purposes.
    Write-Verbose "
Before: $Before"

    ## Sends the disk usage after running the cleanup script to the console for ticketing purposes.
    Write-Verbose "After: $After"

    ## Prompt to scan for large ISO, VHD, VHDX files.
    Function PromptforScan {
        param(
            $ScanPath,
            $title = (Write-Host "Search for large files"),
            $message = (Write-Host "Would you like to scan $ScanPath for ISOs or VHD(X) files?")
        )
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Scans $ScanPath for large files."
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Skips scanning $ScanPath for large files."
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $prompt = $host.ui.PromptForChoice($title, $message, $options, 0)
        switch ($prompt) {
            0 {
                Write-Host "Scanning $ScanPath for any large .ISO and or .VHD\.VHDX files per the Administrators request."
                Write-Verbose ( Get-ChildItem -Path $ScanPath -Include *.iso, *.vhd, *.vhdx -Recurse -ErrorAction SilentlyContinue | 
                        Sort-Object Length -Descending | Select-Object Name, Directory,
                    @{Name = "Size (GB)"; Expression = { "{0:N2}" -f ($_.Length / 1GB) }} | Format-Table | 
                        Out-String -verbose )
            }
            1 {
                Write-Host "The Administrator chose to not scan $ScanPath for large files."
            }
        }
    }
    PromptforScan -ScanPath C:\  # end of function

    ## Completed Successfully!
    Write-Host (Stop-Transcript) 

    Write-host "Script finished" -NoNewline
    Write-Host "[DONE]"

}
Start-Cleanup
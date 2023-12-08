<#
.SYNOPSIS
   Monitor Image Manager Status

.DESCRIPTION
   Checks to see of scheduled Image Manager jobs are completing or failing. 
   Reads Image Manager DB (takes a copy) to check for failing events.
   Checks for IM folder activity.
   Checks for IM Events in Application Log.
   Returns Result.

.PARAMETER SkipWarnFTP (Optional)
   [Boolean] - Default:$False - Enable Warning Checks on FTP Queues

.PARAMETER SkipWarnHSR (Optional)
   [Boolean] - Default:$False - Enable Warning Checks on HSR Sent Logs

.PARAMETER SkipFileSystemChecks (Optional)
   [Boolean] - Default:$False - Enable File System Checks

.PARAMETER SkipEventLogChecks (Optional)
   [Boolean] - Default:$False - Enable Event Log Checks

.PARAMETER FreeSpaceWarnThreshold (Optional)
   [Int] - Default: 10 - Threshold for Percent Free space on a Watch Folder before raising a warning.

.PARAMETER FreeSpaceAlertThreshold (Optional)
   [Int] - Default: 5 - Threshold for Percent Free space on a Watch Folder before raising an Alert.

.OUTPUTS
   Exit Code: 0 = Pass, 1 = Informational, 2 = Warning, 3 = Error

.EXAMPLE
   Win_ShadowProtectIM_Status.ps1
   #No Parameters, defaults apply

.NOTES
   v1.4 12/8/2023 ConvexSERV
   Requires Access 2010 Runtime. Script will attempt to download/install
#>

param (
    [Boolean] $SkipWarnFTP, #Add the ability to disable FTP Warnings
    [Boolean] $SkipWarnHSR, #Add the ability to disable HSR Warnings
    [Boolean] $SkipFileSystemChecks, #Add the ability to disable File System Checks
    [Boolean] $SkipFreeSpaceChecks, #Add the ability to disable Free Space Checks
    [Boolean] $SkipEventLogChecks, #Add the ability to disable Event Log Checks
    [Int] $FreeSpaceWarnThreshold, #Add the ability to disable Event Log Checks
    [Int] $FreeSpaceAlertThreshold #Add the ability to disable Event Log Checks
)

#Environmental Variables:
#$env:shareuser = ""
#$env:sharepass = ""
#$env:hsrshareuser = ""
#$env:hsrsharepass = ""

#If ShareUser/SharePass environmental variable are set, but HSRShareUser/HSRSharePass variables are not,
#Set the HSRShareUser/HSRSharePass variables to match ShareUser/SharePass
if ((Test-Path env:shareuser) -and (-not(Test-Path env:hsrshareuser))){$env:hsrshareuser = $env:shareuser}
if ((Test-Path env:sharepass) -and (-not(Test-Path env:hsrsharepass))){$env:hsrsharepass = $env:sharepass}

#Set Parameter Defaults
if (!$SkipWarnFTP) {$WarnFTP = $True}
if (!$SkipWarnHSR) {$WarnHSR = $True}
if (!$SkipFileSystemChecks) {$FileSystemChecks = $True}
if (!$SkipFreeSpaceChecks) {$FreeSpaceChecks = $True}
if (!$SkipEventLogChecks) {$EventLogChecks = $True}
if (!$FreeSpaceWarnThreshold) {$FreeSpaceWarnThreshold = 5}
if (!$FreeSpaceAlertThreshold) {$FreeSpaceAlertThreshold = 10}

###------------------------------Declare Functions----------------------------------###
###---------------------------------------------------------------------------------###

#Takes in an Index (from a hsr** or ftp** Table), Returns [String] containing the Target Path
Function Get-TargetPath ([Int] $Index) { #Returns String

    ForEach ($drTargetPath in $dtTargetPaths) {

        if ($drTargetPath["Index"] -eq $Index) {
            Return $drTargetPath["Path"]
        }
    }
}

#Takes in an Index (from a w*Files Table), Returns DataRow containing the Watch Path
Function Get-WatchPath ([Int] $Index) { #Returns DataRow

    ForEach ($drWatchPath in $dtWatchPaths) {

        if ($drWatchPath["Index"] -eq $Index) {
            Return $drWatchPath
        }
    }

}

#Takes in a w*Sets Table and Index, Returns DataRow containing the Watch Set
Function Get-WatchSet ([System.Data.DataTable] $Table, [Int] $Index) { #Returns DataRow

    ForEach ($drWatchSet in $Table) {

        if ($drWatchSet["Index"] -eq $Index) {
            Return $drWatchSet
        }
    }
}

#Takes in the Index from the WatchPaths Table and returns [Boolean] $True if a w*Files Table Exists, otherwise returns $False.
Function Check-WatchPathTable ([Int] $Index) { #Returns Boolean

    $Result = $False

    ForEach ($drTableWP in $dtTableList){
    
        [Int]$CurrentTableIndexWP = $drTableWP["name"] -replace "[^0-9]",'' #Extract the index number from the table name
        $CurrentTableNameWP = $drTableWP["name"]
        if (($CurrentTableIndexWP -eq $Index) -and ($CurrentTableNameWP.Substring(0,1) -eq "w")) {

            $Result = $True
            Break
        }
    }
    
    Return $Result
}
###---------------------------------------------------------------------------------###

#Initialize Variables
$NowTime = [DateTime]::Now
$AlertLevel = 0 #0 = Pass, 1 = Informational, 2 = Warning, 3 = Error
$AlertText = ''

#Create c:\ProgramData\TacticalRMM\temp\ if it does't exist.
if (-not(test-path "c:\ProgramData\TacticalRMM\temp\")){
    mkdir "c:\ProgramData\TacticalRMM\temp\"
}

####-------------------------------###
#          Database Checks           #
####-------------------------------###

#Image Manager will have the DB open exclusively (At the MS Access Level, not the FileSystem Level). Copy the DB to Temp.
$IMDBPath = "c:\ProgramData\TacticalRMM\temp\Imagemanager.mdb"
try {
    copy "C:\Program Files (x86)\StorageCraft\ImageManager\ImageManager.mdb" "c:\ProgramData\TacticalRMM\temp\Imagemanager.mdb"
}
catch
{
    $AlertText = "Alert - Failed to make a copy of the ImageManager Database. Please check if ImageManager is actually installed, and if another process has a lock on the .mdb file (Source or Dest)"
    Write-Host $AlertText
    $AlertLevel = 3
    $Host.SetShouldExit($AlertLevel)
    Exit
}

#Attempt to create an OLDDB Connection. Connection will fail if the Access RunTime is not installed
try{
    $conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$IMDBPath;Persist Security Info=False")
    $conn.open()
}
catch
{ 
    Write-Host "Info - Access Runtime Not Installed. Will attempt to download and install..."
    try{
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/4/3/24375141-E08D-4803-AB0E-10F2E3A07AAA/AccessDatabaseEngine_X64.exe" -UseBasicParsing -OutFile "c:\ProgramData\TacticalRMM\temp\AccessDatabaseEngine_X64.exe"
    }
    catch {
        $AlertText = "Alert - MS Access Runtime Download Failed."
        Write-Host $AlertText
        $AlertLevel = 3
        $Host.SetShouldExit($AlertLevel)
        Exit
    }

    if (Test-Path c:\ProgramData\TacticalRMM\temp\AccessDatabaseEngine_X64.exe) {
    
        Write-Host "Info - File Downloaded. Will attempt to install..."
        
        try {
            Start-Process -NoNewWindow -FilePath "c:\ProgramData\TacticalRMM\temp\AccessDatabaseEngine_X64.exe" -ArgumentList '/q' -Wait
        }
        catch {
            $AlertText = "Alert - MS Access Runtime Install Failed."
            Write-Host $AlertText
            $AlertLevel = 3
            $Host.SetShouldExit($AlertLevel)
            Exit
        }

        Write-Host "Info - MS Access Runtime Install Succeeded. Try to open the connection again..."
        try {
            $conn.close()
            $conn = New-Object System.Data.OleDb.OleDbConnection("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$filename;Persist Security Info=False")
            $conn.open()
        }
        catch {
            $AlertText = "Alert - DB Connection failed after installing Access Runtime."
            Write-Host $AlertText
            $AlertLevel = 3
            $Host.SetShouldExit($AlertLevel)
            Exit
        }
    }
}

$cmd=$conn.CreateCommand()

#Get All Tables in the DB
$cmd.CommandText="select MSysObjects.name from MSysObjects where MSysObjects.type In (1,4,6) and MSysObjects.name not like '~*' and MSysObjects.name not like 'MSys*' order by MSysObjects.name"
$rdr = $cmd.ExecuteReader()
$dtTableList = New-Object System.Data.Datatable
$dtTableList.Load($rdr)

#Add an Ignore Column to the Table List Table
$NoOutput = $dtTableList.Columns.Add("Ignore", [Boolean])


#Get the TargetPaths Table
$cmd.CommandText="select * from TargetPaths"
$rdr = $cmd.ExecuteReader()
$dtTargetPaths = New-Object System.Data.Datatable
$dtTargetPaths.Load($rdr)

#Add an Ignore Column to the TargetPaths Table
$NoOutput = $dtTargetPaths.Columns.Add("Ignore", [Boolean])


#Get the WatchPaths Table
$cmd.CommandText="select * from WatchPaths"
$rdr = $cmd.ExecuteReader()
$dtWatchPaths = New-Object System.Data.Datatable
$dtWatchPaths.Load($rdr)

#Add an Ignore Column to the TargetPaths Table
$NoOutput = $dtWatchPaths.Columns.Add("Ignore", [Boolean])

#Walk through the tablelist and mark the tables we don't need
ForEach ($drTable in $dtTableList) {

    #Ignore System Tables
    if ($drTable["name"] -like "MSys*") {$drTable["Ignore"] = $true}

    #Ignore HSR Queue and Remote Tables
    elseif (($drTable["name"] -like "hsr*Queue") -or ($drTable["name"] -like "hsr*Remote")) {$drTable["Ignore"] = $true}

    #Ignore FTP Sent and Remote Tables
    elseif (($drTable["name"] -like "ftp*Sent") -or ($drTable["name"] -like "ftp*Remote")) {$drTable["Ignore"] = $true}

    #Ignore Adv Tables
    elseif ($drTable["name"] -like "adv*Verify") {$drTable["Ignore"] = $true}

    #Include w*Files,w*Sets,TargetPaths and WathcPaths Tables
    elseif (($drTable["name"] -eq "TargetPaths") -or ($drTable["name"] -eq "WatchPaths")) {$drTable["Ignore"] = $false}
    #excluded (($drTable["name"] -like "w*Files") -or ($drTable["name"] -like "w*Sets") -or )

    else {

        $CurrentTableName = $drTable["name"]
    
        #Ignore ftp tables if they are empty
        if ($CurrentTableName.SubString(0,3) -eq "ftp") {
            
            $cmd.CommandText="select count(*) from $CurrentTableName"
            $CurrentTableCount = $cmd.ExecuteScalar()
            if ($CurrentTableCount -eq 0) {
                $drTable["Ignore"] = $true
            }
            else {$drTable["Ignore"] = $false}

            #Ignore all FTP TargetPaths, we don't need to check the filesystem for FTP
            [Int]$CurrentTableIndex = $drTable["name"] -replace "[^0-9]",'' #Extract the index number from the table name
            ForEach ($drTargetPath in $dtTargetPaths) {
                if ($drTargetPath["Index"] -eq $CurrentTableIndex){
                    $drTargetPath["Ignore"] = $True
                }

            }

        }

        #Ignore remaining hsr if they are empty
        if ($CurrentTableName.SubString(0,3) -eq "hsr") {
            
            $cmd.CommandText="select count(*) from $CurrentTableName"
            $CurrentTableCount = $cmd.ExecuteScalar()
            if ($CurrentTableCount -eq 0) {
                $drTable["Ignore"] = $true
                #Ignore HSR TargetPaths if the cooresponding table is empty
                [Int]$CurrentTableIndex = $drTable["name"] -replace "[^0-9]",'' #Extract the index number from the table name
                ForEach ($drTargetPath in $dtTargetPaths) {
                    if ($drTargetPath["Index"] -eq $CurrentTableIndex){
                        $drTargetPath["Ignore"] = $True
                    }

                }
            }
            else {$drTable["Ignore"] = $false}
        }

        #Ignore remaining w tables if they are empty
        if ($CurrentTableName.SubString(0,1) -eq "w") {
            
            $cmd.CommandText="select count(*) from $CurrentTableName"
            $CurrentTableCount = $cmd.ExecuteScalar()
            if ($CurrentTableCount -eq 0) {
                $drTable["Ignore"] = $true
                #Mark the index in WatchPaths too
                [Int]$CurrentTableIndex = $drTable["name"] -replace "[^0-9]",'' #Extract the index number from the table name
                ForEach ($drWatchPath in $dtWatchPaths) {
                    if ($drWatchPath["Index"] -eq $CurrentTableIndex){
                        $drWatchPath["Ignore"] = $True
                    }
                }
            }
            else {$drTable["Ignore"] = $false}
        }
    }
}
#Also Ignore Watch Paths that contain "Archive", "RestoreTest", "Permanently Retain"
ForEach ($drWatchPath in $dtWatchPaths) {
    if (($drWatchPath["Path"] -like  "*Archive*") -or ($drWatchPath["Path"] -like  "*RestoreTest*") -or ($drWatchPath["Path"] -like  "*Permanently Retain*")){
        $drWatchPath["Ignore"] = $True
    }
    else {
        $drWatchPath["Ignore"] = $False
    }
}

#Walk through the tablelist again to run our checks
ForEach ($drTable in $dtTableList) {

    [Int]$CurrentTableIndex = $drTable["name"] -replace "[^0-9]",'' #Extract the index number from the table name
    $CurrentTableName = $drTable["name"]

    #Skip any table flagged to be ignored
    if (-not ($drTable["Ignore"])) {
    
        #Check FTP Queue Tables - Warn on items in the Queue older than 4 days (If Enabled)
        if (($drTable["name"] -like "ftp*Queue") -and $WarnFTP){

            $cmd.CommandText="select Name, CreateTime, FileSize from $CurrentTableName"
            $rdr = $cmd.ExecuteReader()
            $dtFTPQueue = New-Object System.Data.Datatable
            $dtFTPQueue.Load($rdr)

            #Walk the FTP Queue Table
            ForEach ($drFTPQueue in $dtFTPQueue){
                If ($drFTPQueue["CreateTime"] -lt (Get-Date).Date.AddDays(-4)){

                    #Set AlertLevel to Warn if not already set the same or higher
                    If ($AlertLevel -le 1) {
                        $AlertLevel = 2   
                    }

                    #Get the Target Path for the Current Table
                    $CurrentTargetPath = Get-TargetPath -Index $CurrentTableIndex
                    $curFileSize = [math]::round($drFTPQueue["FileSize"] /1Gb, 3)
                    $curFileName = $drFTPQueue["Name"]
                    $curFileSent = $drFTPQueue["Sent"] 

                    #Set AlertText if not already set
                    If ($AlertText -eq "") {
                        $AlertText = "FTP Item in Queue is older than 4 Days ( File: $CurrentTargetPath\$curFileName, Size: $curFileSize GB, Sent: $curFileSent)"
                    }

                    #Write to StdOut Result
                    Write-Host "FTP Item in Queue is older than 4 Days ( File: $CurrentTargetPath\$curFileName, Size: $curFileSize GB, Sent: $curFileSent)"
                }
            }
        }

        #Check HSR Sent Tables - Warn if the latest entry is older than 4 days
        if (($drTable["name"] -like "hsr*Sent") -and $WarnHSR){

            $cmd.CommandText="select top 1 Name, CreateTime, FileSize, Sent, BytesSent from $CurrentTableName order by Sent DESC"
            $rdr = $cmd.ExecuteReader()
            $dtHSRSent = New-Object System.Data.Datatable
            $dtHSRSent.Load($rdr)

            #Walk the HSR Queue Table
            ForEach ($drHSRSent in $dtHSRSent){
                If ($drHSRSent["Sent"] -lt (Get-Date).Date.AddDays(-4)){

                    #Get the Target Path for the Current Table
                    $CurrentTargetPath = Get-TargetPath -Index $CurrentTableIndex
                    $curFileSize = [math]::round($drHSRSent["FileSize"] /1Gb, 3)
                    $curFileName = $drHSRSent["Name"]
                    $curFileSent = $drHSRSent["Sent"] 

                    #Check if the Target Path actually exists. 
                    #If it doesn't the entry is probably not valid because IM doesn't clean up the DB.
                    if (($CurrentTargetPath.substring(0,2) -eq "\\") -and (Test-Path env:hsrshareuser) -and (Test-Path env:hsrsharepass)){
                        Try{
                            #Target Path will be a complete path with a filename. Strip the path down to the hostname and share.
                            $SplitPath = $CurrentTargetPath.split('\',5)
                            $CurrentHostName = $SplitPath[2]
                            $CurrentShareName = $SplitPath[3]
                            $CurrentTestPath = "\\$CurrentHostName\$CurrentShareName" 
                            $TargetPathSMB = New-SmbMapping -remotepath $CurrentTestPath -UserName $env:hsrshareuser -Password $env:hsrsharepass
                            $TargetPathExists = Test-Path "$CurrentTargetPath\$curFileName"
                            $TargetPathSMB.Dispose()
                            }
                        Catch {
                            $TargetPathExists = $False
                        }
                    }
                    else {
                        $TargetPathExists = Test-Path "$CurrentTargetPath\$curFileName"
                    }

                    If ($TargetPathExists){

                        #Set AlertLevel to Warn if not already set the same or higher
                        If ($AlertLevel -le 1) {
                            $AlertLevel = 2   
                        }

                        #Set AlertText if not already set
                        If ($AlertText -eq "") {
                            $AlertText = "Warning - HSR Item in has not been updated in 4 Days ( File: $CurrentTargetPath\$curFileName, Size: $curFileSize GB, Sent: $curFileSent)"
                        }

                        #Write to StdOut Result
                        Write-Host "Warning - HSR Item in has not been updated in 4 Days ( File: $CurrentTargetPath\$curFileName, Size: $curFileSize GB, Sent: $curFileSent)"
                    }                
                }
            }
        }

        #Check W Files Tables - Alert if there are any entries older than 4 days, or if VerifyFailed is not empty, or if VerifyStatus != 1
        if ($drTable["name"] -like "w*Files"){

            $cmd.CommandText="select Name, ImageType, FileSize, LastVerified, VerifyStatus, VerifyFailed from $CurrentTableName order by LastVerified DESC"
            $rdr = $cmd.ExecuteReader()
            $dtWFiles = New-Object System.Data.Datatable
            $dtWFiles.Load($rdr)

            #Get the Watch Path for the Current Table
            $drCurrentWatchPath = Get-WatchPath -Index $CurrentTableIndex
            $CurrentWatchPath = $drCurrentWatchPath["Path"]

            #Check the first Row (Newest Entry)
            if ($dtWFiles.Rows[0]["LastVerified"] -lt (Get-Date).Date.AddDays(-4)){

                if (-not ($drCurrentWatchPath["Ignore"])) {

                    #Format Variables for Output
                    $curFileSize = [math]::round($dtWFiles.Rows[0]["FileSize"] /1Gb, 3)
                    $curFileName = $dtWFiles.Rows[0]["Name"]
                    $curFileVerified = $dtWFiles.Rows[0]["LastVerified"] 

                    #Set AlertLevel to Alert if not already set the same or higher
                    If ($AlertLevel -le 2) {
                        $AlertLevel = 3   
                    }
                
                    #Set AlertText
                    $AlertText = "Alert - File has not been verified in 4 Days ( File: $CurrentWatchPath\$curFileName, Size: $curFileSize GB, Verified: $curFileVerified)"
                    #Write to StdOut Result
                    Write-Host $AlertText
                }
            }

            #Walk the W Files Table, looking for verification failures
            ForEach ($drWFiles in $dtWFiles){
                If (($drWFiles["VerifyStatus"] -ne 1 ) -and ($drWFiles["VerifyStatus"] -eq "" )){

                    #Set AlertLevel to Alert if not already set the same or higher
                    If ($AlertLevel -le 2) {
                        $AlertLevel = 3   
                    }

                    #Format Variables for Output
                    $curFileSize = [math]::round($drWFiles["FileSize"] /1Gb, 3)
                    $curFileName = $drWFiles["Name"]
                    $curFileVerified = $drWFiles["LastVerified"] 

                    #Set AlertText if not already set
                    $AlertText = "Alert - File verification FAILED! ( File: $CurrentTargetPath\$curFileName, Size: $curFileSize GB, Verified: $curFileVerified)"
                    #Write to StdOut Result
                    Write-Host $AlertText
                }
            }
        }
    }
}
#Write Output
if ($AlertLevel -eq 0) {
    Write-Output "Info - Database Checks Passed"
}

####-------------------------------###
#          Filesystem Checks         #
####-------------------------------###

#Perform FileSystem Checks (If Enabled)
if ($FileSystemChecks) {

    #Check Target Paths Table - Warn if file timestamps are older than 4 days
    ForEach ($drTargetPath in $dtTargetPaths) {
    
        if (-not($drTargetPath["Ignore"])){

            $CurrentTargetPath = $drTargetPath["Path"]
            if (($CurrentTargetPath.substring(0,2) -eq "\\") -and (Test-Path env:hsrshareuser) -and (Test-Path env:hsrsharepass)){
                Try{
                    $NoOutput = New-SmbMapping -remotepath $CurrentTargetPath -UserName $env:hsrshareuser -Password $env:hsrsharepass
                    $TargetPathExists = Test-Path($drTargetPath["Path"])
                    }
                Catch {
                    $TargetPathExists = $False
                }
            }
            else {
                $TargetPathExists = Test-Path($drTargetPath["Path"])
            }

            #Check that file Exists and that the file date is recent
            if($TargetPathExists){
                $TargetFile = Get-ChildItem $drTargetPath["Path"]
                if ($TargetFile.LastWriteTime -lt (Get-Date).Date.AddDays(-4)) {

                    #Format Variables for Output
                    $curFileName = $drTargetPath["Path"]
                    $curFileLastWrite = $TargetFile.LastWriteTime
                    $curFileSize = [math]::round($TargetFile.Length /1Gb, 3)

                    #Warn if HSR File TimeStamp is older than 4 days
                    #Set AlertLevel to Alert if not already set the same or higher
                    If ($AlertLevel -le 1) {
                        $AlertLevel = 2   
                    }
                    #Set AlertText
                    $AlertText = "Warning - HSR File timeStamp is older than 4 Days ( File: $CurrentTargetPath\$curFileName, Size: $curFileSize GB, Created: $curFileLastWrite)"
                    #Write to StdOut Result
                    Write-Host $AlertText
                }
            }
            else
            {
                #Format Variables for Output
                $curFileName = $drTargetPath["Path"]

                #Alert if HSR File Missing or Inaccessible
                #Set AlertLevel to Alert if not already set the same or higher
                If ($AlertLevel -le 2) {
                    $AlertLevel = 3   
                }
                #Set AlertText
                $AlertText = "Alert - HSR file is Missing or Inaccessible ( File: $curFileName)"

                #Write to StdOut Result
                Write-Host $AlertText
            }
        }
    }

    #Check Watch Paths Table - Alert if file timestamps are older than 4 days, Warn if Base images are older than 1 Year, Alert if Base Images are older than 2 years.
    ForEach ($drWatchPath in $dtWatchPaths) {

        if (-not($drWatchPath["Ignore"]) -and (Check-WatchPathTable($drWatchPath["Index"]))){

            $CurrentWatchPath = $drWatchPath["Path"]
            if (($CurrentWatchPath.substring(0,2) -eq "\\") -and (Test-Path env:shareuser) -and (Test-Path env:sharepass)){
                Try{
                    $WatchPathSMB = New-SmbMapping -remotepath $CurrentWatchPath -UserName $env:shareuser -Password $env:sharepass
                    $WatchPathExists = Test-Path($drWatchPath["Path"])
                    $CurrentWatchPathLocal = $False
                    }
                Catch {
                    $WatchPathExists = $False
                }
            }
            else {
                $WatchPathExists = Test-Path($drWatchPath["Path"])
                $CurrentWatchPathLocal = $True
            }

            #Check that file Exists and that the file date is recent
            if($WatchPathExists){
                
                #Get all *.Sp? files in the path, sort by Creation Time (Descending)
                $WatchFiles = Get-ChildItem $drWatchPath["Path"] -Filter "*.sp?" | sort CreationTime -Descending
                
                if ($WatchFiles.Length -gt 0){

                    #Check the newest file to see if it's older than 4 days
                    if ($WatchFiles[0].LastWriteTime -lt (Get-Date).Date.AddDays(-4)) {

                        #Format Variables for Output
                        $curFileName = $WatchFiles[0].FullName
                        $curFileLastWrite = $WatchFiles[0].LastWriteTime
                        $curFileSize = [math]::round($WatchFiles[0].Length /1Gb, 3)

                        #Alert if IM File TimeStamp is older than 4 days
                        #Set AlertLevel to Alert if not already set the same or higher
                        If ($AlertLevel -le 1) {
                            $AlertLevel = 3   
                        }
                        #Set AlertText
                        $AlertText = "Alert - Last IM File written timeStamp is older than 4 Days ( File: $curFileName, Size: $curFileSize GB, Created: $curFileLastWrite)"
                        #Write to StdOut Result
                        Write-Host $AlertText
                    }
                
                    #Get all *.Spf (Base) files in the path, sort by Creation Time (Descending)
                    $WatchFiles = Get-ChildItem $drWatchPath["Path"] -Filter "*.sp?" | sort CreationTime -Descending
                
                    #Check the newest file to see if it's older than 1 Year (But Less than 2 Years)
                    if ($WatchFiles[0].LastWriteTime -lt (Get-Date).Date.AddDays(-365) -and $WatchFiles[0].LastWriteTime -ge (Get-Date).Date.AddDays(-731)) {

                        #Format Variables for Output
                        $curFileName = $WatchFiles[0].FullName
                        $curFileLastWrite = $WatchFiles[0].LastWriteTime
                        $curFileSize = [math]::round($WatchFiles[0].Length /1Gb, 3)

                        #Warn if SPX Base File TimeStamp is older than 1 Year
                        #Set AlertLevel to Alert if not already set the same or higher
                        If ($AlertLevel -le 1) {
                            $AlertLevel = 2   
                        }
                        #Set AlertText
                        $AlertText = "Warning - SPX Base is over 1 Yr. Old. ( File: $curFileName, Size: $curFileSize GB, Created: $curFileLastWrite)"
                        #Write to StdOut Result
                        Write-Host $AlertText
                    }
                    elseif ($WatchFiles[0].LastWriteTime -lt (Get-Date).Date.AddDays(-731)) {

                        #Format Variables for Output
                        $curFileName = $WatchFiles[0].FullName
                        $curFileLastWrite = $WatchFiles[0].LastWriteTime
                        $curFileSize = [math]::round($WatchFiles[0].Length /1Gb, 3)

                        #Warn if SPX Base File TimeStamp is older than 2 Years.
                        #Set AlertLevel to Alert if not already set the same or higher
                        If ($AlertLevel -le 1) {
                            $AlertLevel = 2   
                        }
                        #Set AlertText
                        $AlertText = "Alert - SPX Base is over 2 Yrs. Old. ( File: $curFileName, Size: $curFileSize GB, Created: $curFileLastWrite)"
                        #Write to StdOut Result
                        Write-Host $AlertText
                    }
                }
                
                #Check Free Space on Watch Path
                if ($FreeSpaceChecks){

                    if ($CurrentWatchPathLocal) { #Local Path
                        $CurrentWatchPathDriveLetter = $CurrentWatchPath.Substring(0,1)
                        $drive = get-psdrive $CurrentWatchPathDriveLetter
                        $free = $drive.Free
                        $used = $drive.Used
                        $total = $free + $used
                    }
                    else { #UNC Path

                        #Target Path might be a complete path with a subfolder name. Strip the path down to the hostname and share.
                        $SplitPath = $CurrentWatchPath.split('\',5)
                        $CurrentHostName = $SplitPath[2]
                        $CurrentShareName = $SplitPath[3]
                        $CurrentTestPath = "\\$CurrentHostName\$CurrentShareName" 

                        $drive = (New-Object -com scripting.filesystemobject).getdrive("$CurrentTestPath")
                        $free = $drive.FreeSpace
                        $total = $drive.TotalSize
                        $used = ($total - $free)
              
                    }

                    #Clean up the total sizes
                    $totalGB = ($total / 1GB)
                    $totalPretty = [math]::Round($totalGB,2)

                    $usedGB = ($used / 1GB)
                    $usedPretty = [math]::Round($usedGB,2)

                    $usedPercent = ($used / $total)*100
                    $usedPercentPretty = [math]::Round($usedPercent)

                    $freePercent = ($free / $total)*100
                    $freePercentPretty = [math]::Round($freePercent)

                    $freeGB = ($free / 1GB)
                    $freePretty = [math]::Round($freeGB,2)

                    #Warn on 10% or less disk space or less
                    if (($freePercentPretty -le 10) -and ($freePercentPretty -gt 5)){

                        #Set AlertLevel to Warn if not already set the same or higher
                        If ($AlertLevel -le 1) {
                            $AlertLevel = 2   
                        }
                        #Set AlertText
                        $AlertText = "Warn - IM Destination Free Space ($freePercentPretty%) is at a low level. (Threshold: $FreeSpaceWarnThreshold%, $freePretty GB free of $totalPretty GB)"

                        #Write to StdOut Result
                        Write-Host $AlertText

                    }
                    #Alert on 5% or less free disk space
                    elseif ($freePercentPretty -le 5){

                        #Set AlertLevel to Alert if not already set the same or higher
                        If ($AlertLevel -le 2) {
                            $AlertLevel = 3   
                        }
                        #Set AlertText
                        $AlertText = "Alert - IM Destination Free Space ($freePercentPretty%) is at a Critical Level.(Threshold: $FreeSpaceAlertThreshold%, $freePretty GB free of $totalPrettyGB )"

                        #Write to StdOut Result
                        Write-Host $AlertText
                    
                    }
                    else{
                        Write-Host "Info - IM Destination Free Space ($freePercentPretty%) is (OK) (Threshold: $FreeSpaceWarnThreshold%, $freePretty GB free of $totalPretty GB)"
                    }
                }            
            }
            else
            {
                #Format Variables for Output
                $curFileName = $drWatchPath["Path"]

                #Alert if IM Destination Missing or Inaccessible
                #Set AlertLevel to Alert if not already set the same or higher
                If ($AlertLevel -le 2) {
                    $AlertLevel = 3   
                }
                #Set AlertText
                $AlertText = "Alert - IM Destination is Missing or Inaccessible ( File: $curFileName)"

                #Write to StdOut Result
                Write-Host $AlertText
            }
        }
    }
}    
#Write Output
if ($AlertLevel -eq 0) {
    Write-Output "Info - File System Checks Passed"
}

####-------------------------------###
#          Event Log Checks          #
####-------------------------------###

#Perform Event Log Checks (If Enabled)
if ($EventLogChecks) {

    #ImageManager Event IDs: Windows Logs> Application{source "StorageCraft ImageManager"}]:

    #Information Codes are from 1100 to 1120:
    $IM_Success = 1120 # Successful collapse occurred which created the file listed


    $IM_FailedCollapse = 1121 #Failed collapse
    $IM_Error = 1122 #Reserved
    $IM_DataCorruption = 1123 #Data corruption (a file failed to verify)
    $IM_IncompleteChain = 1124 #Incomplete chain (missing a file necessary to form a complete chain)
    $IM_ProcessingError = 1125 #Processing error (error preparing for collapse / verify operations such as trying to sync files with database)
    $IM_ReplicationError = 1126 #Replication error (failed replication will retry next time a file is verified)
    $IM_HSRError = 1127 #HSR error
    $IM_CriticalError = 1128 #Critical error (the service must be restarted due to an unrecoverable error)
    $IM_Exception = 1129 #Exception (ImageManager will retry the failed operation later so the service does not need to be restarted)
    #Note: In ImageManager release version 7.0.2 event IDs 1125 and above were shifted up by one digit so Event ID 1126 = Processing error, etc.  These were shifted back to the original values in the next release.

    #Check Windows Event Log for ImageManager Events Occurring Today (After Midnight)
    $Events = Get-EventLog -LogName Application -Source "StorageCraft ImageManager" -After (Get-Date).Date

    #If there are no Events...
    If ($Events.Count -eq 0){

        #Check Windows Event Log for ImageManager Events Occurring Today (After Midnight)
        $MoreEvents = Get-EventLog -LogName Application -Source "StorageCraft ImageManager" -After (Get-Date).Date.AddDays(-4)

        #If there have been no events, look back another 4 days.
        If ($MoreEvents.Count -eq 0){

            #We haven't had any activity in over 4 days. Fail the Check.
            $AlertText = "Alert - There has not been any activity in over 4 days. Please check that Image Manage and SPX are both running. (EventLog-NoEvents)"
            $AlertLevel = 3

        } Else { #There are Events in the 3-Day search...

            #Walk the 3 days of events, looking for errors.
            ForEach ($Event in $MoreEvents) {

                If ($Event.InstanceID -gt 1120){

                    Switch ($Event.InstanceID) {

                        #Error codes are from 1121 to 1129:
                        $IM_FailedCollapse { #1121 Failed collapse
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break                       
                        }

                        $IM_Error { #1122 Reserved
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        } 

                        $IM_DataCorruption { # 1123 Data corruption (a file failed to verify)
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        } 

                        $IM_IncompleteChain { # 1124 Incomplete chain (missing a file necessary to form a complete chain)
                            #Event is an Error
                            $AlertText = "Alert:(EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_ProcessingError { #1125 Processing error (error preparing for collapse / verify operations such as trying to sync files with database)
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_ReplicationError { #1126 Replication error (failed replication will retry next time a file is verified)
                            #Event is a Warning (Potentially Recoverable)
                            if ($AlertText = ""){
                                $AlertText = "Warning: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            }
                            if ($AlertLevel -le 2) {
                                $AlertLevel = 2
                            }
                            Write-Output = "Warning: (EventLog 3-Day)  ID:" + $Event.InstanceID + $Event.Message
                            break
                        }

                        $IM_HSRError { #1127 HSR error
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_CriticalError { #1128 Critical error (the service must be restarted due to an unrecoverable error)
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_Exception { #Exception (ImageManager will retry the failed operation later so the service does not need to be restarted)
                            #Event is a Warning (Potentially Recoverable)
                            if ($AlertText = ""){
                                $AlertText = "Warning: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            }
                            if ($AlertLevel -le 2) {
                                $AlertLevel = 2
                            }
                            Write-Output = "Warning: (EventLog 3-Day) ID:"$Event.InstanceID $Event.Message
                            break
                        }
                    }
                } ElseIf ($Event.InstanceID -le 1120){
                    #Event is Informational
                    #Write-Output = "Info: (EventLog 3-Day) "$Event.Message
                }
            }
        }
    } Else { #There are Events in the 1-Day search...

        #Walk the 1 day of events, looking for errors.
        ForEach ($Event in $Events) {

            If ($Event.InstanceID -gt 1120){

                    Switch ($Event.InstanceID) {

                        #Error codes are from 1121 to 1129:
                        $IM_FailedCollapse { #1121 Failed collapse
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 1-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break                       
                        }

                        $IM_Error { #1122 Reserved
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 1-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        } 

                        $IM_DataCorruption { # 1123 Data corruption (a file failed to verify)
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 1-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        } 

                        $IM_IncompleteChain { # 1124 Incomplete chain (missing a file necessary to form a complete chain)
                            #Event is an Error
                            $AlertText = "Alert:(EventLog 1-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_ProcessingError { #1125 Processing error (error preparing for collapse / verify operations such as trying to sync files with database)
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 1-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_ReplicationError { #1126 Replication error (failed replication will retry next time a file is verified)
                            #Event is a Warning (Potentially Recoverable)
                            if ($AlertText = ""){
                                $AlertText = "Warning: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            }
                            if ($AlertLevel -le 2) {
                                $AlertLevel = 2
                            }
                            Write-Output = "Warning: (EventLog 3-Day) ID:" $Event.InstanceID $Event.Message
                            break
                        }

                        $IM_HSRError { #1127 HSR error
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 1-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_CriticalError { #1128 Critical error (the service must be restarted due to an unrecoverable error)
                            #Event is an Error
                            $AlertText = "Alert: (EventLog 1-Day) ID:" + $Event.InstanceID + $Event.Message
                            Write-Output $AlertText
                            $AlertLevel = 3
                            break
                        }

                        $IM_Exception { #Exception (ImageManager will retry the failed operation later so the service does not need to be restarted)
                            #Event is a Warning (Potentially Recoverable)
                            if ($AlertText = ""){
                                $AlertText = "Warning: (EventLog 3-Day) ID:" + $Event.InstanceID + $Event.Message
                            }
                            if ($AlertLevel -le 2) {
                                $AlertLevel = 2
                            }
                            Write-Output = "Warning: (EventLog 3-Day)  ID:" $Event.InstanceID $Event.Message
                            break
                        }
                    }

            } ElseIf ($Event.InstanceID -le 1120){

                #Event is Informational
                #Write-Output = "Info: (EventLog 1-Day) "$Event.Message
            }
        }
    }
}
#Write Output
if ($AlertLevel -eq 0) {
    Write-Output "Info - Event Log Checks Passed"
}

#Close the DB Connection
$conn.Close()
#Give the DB Time to Close
Start-Sleep -Seconds 1

#Delete the Database Copy
try{
    Del "c:\ProgramData\TacticalRMM\temp\Imagemanager.mdb"
}
catch{
    Write-Output "Couldn't delete DB."
}
#Report back to the RMM
if ($AlertLevel -gt 0) {
    Write-Output $AlertText
}
$Host.SetShouldExit($AlertLevel)
Exit

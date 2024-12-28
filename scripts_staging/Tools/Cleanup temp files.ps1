<# 
.SYNOPSIS
    Automate cleaning up the C:\ drive with low disk space warning.

.DESCRIPTION
    Cleans the C: drive's Windows Temporary files, Windows SoftwareDistribution folder, 
    the local users Temporary folder, IIS logs(if applicable) and empties the recycle bin. 
    By default this script leaves files that are newer than 30 days old however this variable can be edited.
    This script will typically clean up anywhere from 1GB up to 15GB of space from a C: drive.


.NOTES
    Author: SAN
    Date: 01.01.24
    #public
    Dependencies: 
        Cleaner Snippet

.EXEMPLE
    DaysToDelete=25

.CHANGELOG
    25.10.24 SAN Changed to 25 day of IIS logs
    19.11.24 SAN Added adobe updates folder to cleanup
    19.11.24 SAN removed colors
    19.11.24 SAN added cleanup of search index
    17.12.24 SAN Full code refactoring, set a single value for file expiration
    
.TODO
    Integrate bleachbit this would help avoid having to update this script too often.
    
#>


{{Cleaner}}
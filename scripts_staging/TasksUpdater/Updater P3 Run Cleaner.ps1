<#
.SYNOPSIS
    Poor's man WSUS/SCCM part 3 - Temporary File Cleanup
    This PowerShell script is the third phase of a multi-part automation process, focused on cleaning temporary files and optimizing VHDX files. 
    It is designed to run daily and uses a parsed schedule to determine whether cleanup tasks should be executed on the current date.

.DESCRIPTION
    The script automates system cleanup tasks to maintain optimal performance and storage utilization:
    * Runs Daily
    * Utilizes the `Updater P3.5 Schedules parser` snippet to check if cleanup tasks are scheduled for the current date.
    * Logs results using the `Logging` snippet.
    * Runs the `Cleaner` snippet to delete temporary and unnecessary files.
    * Executes the `VHDXCleaner` snippet to optimize VHDX files.

    

.EXAMPLE
    Schedules={{agent. Schedules}}
    Company_folder_path={{global.Company_folder_path}}
    VHDX_PATH={{agent.VHDXPath}}

.NOTES
    Author: SAN // MSA
    Date: 06.08.2024
    Dependencies: 
        Logging snippet for logging
        Updater P3.5 Schedules parser snippet for parsing the date
        Cleaner & VHDXCleaner snippet to run the actual cleans
    #public


.CHANGELOG 
    28.11.24 SAN Incorporated VHDX cleaner.
    13.12.24 SAN Split logging from parser.
#>



# Name will be used for both the name of the log file and what line of the Schedules to parse
$PartName = "TempFileCleanup"

# Call the parser snippet env Schedules will be passed
{{Updater P3.5 Schedules parser}}

# Call the logging snippet env Company_folder_path will be passed
{{Logging}}

Write-Output "Start Cleaner:"
{{Cleaner}}

Write-Output "-----------------------------------------------------"
Write-Output "Start VHDX Cleaner:"

{{VHDXCleaner}}
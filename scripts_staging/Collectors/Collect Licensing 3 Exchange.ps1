<#
.SYNOPSIS
    Retrieves the number of Exchange mailboxes for licensing compliance reporting.

.DESCRIPTION
    This script uses the Exchange Management Shell to determine the number of mailboxes 
    associated with a specific Exchange Server CAL (Client Access License), 
    such as the "Exchange Server 2016 Standard CAL." It ensures the Exchange snap-in is loaded and 
    captures the mailbox count for licensing purposes.

.NOTES
    Author: SAN
    Date: 01.01.24
    #public

.TODO
    Extend support to handle multiple CAL types dynamically.
    
#>

function Get-ExchangeMailboxCount {
    # Launch the Exchange Management Shell
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

    # Check if the Exchange snap-in is available
    if (Get-PSSnapin -Registered | Where-Object { $_.Name -eq 'Microsoft.Exchange.Management.PowerShell.SnapIn' }) {
        try {
            # Run the command directly in the Exchange Management Shell and capture the count
            $mailboxCount = (Get-ExchangeServerAccessLicenseUser -LicenseName "Exchange Server 2016 Standard CAL" | Measure-Object).Count
            "Number of Exchange Mailboxes: $mailboxCount"
        } catch {
            "Error running command: $_"
        }
    } else {
        ""
    }
}
Get-ExchangeMailboxCount
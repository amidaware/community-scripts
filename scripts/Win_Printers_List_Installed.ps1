# You can run this as a one-off script and save to Notes,
# setup a custom field and use a collector task
# or use tasks and check output

Get-WmiObject -class Win32_printer | Format-List Name, PortName, Shared

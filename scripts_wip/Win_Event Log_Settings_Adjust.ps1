Limit-Eventlog -Logname Application -MaximumSize 4MB -OverflowAction OverwriteAsNeeded
Limit-Eventlog -Logname HardwareEvents -MaximumSize 4MB -OverflowAction OverwriteAsNeeded
Limit-Eventlog -Logname "Internet Explorer" -MaximumSize 4MB -OverflowAction OverwriteAsNeeded
Limit-Eventlog -Logname "Key Management Service" -MaximumSize 4MB -OverflowAction OverwriteAsNeeded
Limit-Eventlog -Logname Security -MaximumSize 20MB -OverflowAction OverwriteAsNeeded
Limit-Eventlog -Logname System -MaximumSize 4MB -OverflowAction OverwriteAsNeeded
Limit-Eventlog -Logname "Windows Powershell" -MaximumSize 4MB -OverflowAction OverwriteAsNeeded
Get-Eventlog -List
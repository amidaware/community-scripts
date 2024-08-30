# Check if any arguments were passed
if ($args.Count -eq 0) {
    Write-Output "No arguments passed. Listing all processes:`n----------------------------------`n"

    # Get all processes and select the Name and ID
    $processes = Get-Process | Select-Object Name, Id

    # Loop through each process and format the output
    foreach ($process in $processes) {
        $processName = $process.Name  # Renamed variable
        $processId = $process.Id      # Renamed variable

        # Format the output with right-aligned PID and process name
        $formattedOutput = "{0,-6} {1}" -f $processId, $processName

        # Print the formatted output
        Write-Output $formattedOutput
    }
} else {
    # Loop through each argument passed
    foreach ($pidArgument in $args) {
        # Check if the argument is a valid PID (an integer)
        if ($pidArgument -match '^\d+$') {
            try {
                # Attempt to get the process with the specified PID
                $process = Get-Process -Id $pidArgument -ErrorAction Stop

                # Kill the process
                $process.Kill()
                Write-Output "Process with PID $pidArgument ($($process.Name)) has been terminated."
            } catch {
                Write-Output "No process with PID $pidArgument found, or an error occurred."
            }
        } else {
            Write-Output "Invalid argument: '$pidArgument'. Please provide a valid PID number."
        }
        
        # Print an empty line between each kill operation
        Write-Output ""
    }
}
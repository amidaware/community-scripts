########
### You can run this as a one of Script and save to Notes, setup a custom field and use a colelctor task or use tasks and check output

get-WmiObject -class Win32_printer | fl Name, PortName, Shared

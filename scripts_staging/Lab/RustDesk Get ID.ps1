#public
#grab public id of restdesk to set a custom field

#V1
$ErrorActionPreference= 'silentlycontinue'

cd $env:ProgramFiles\RustDesk\
.\RustDesk.exe --get-id | out-host

exit

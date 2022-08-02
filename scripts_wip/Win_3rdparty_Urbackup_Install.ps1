#load parameters
param (
    [string] $urbackupserver,
    [string] $urbackupport,
    [string] $urbackupkey,
    [string] $urbackupcomputername
)

#install urbackup client with chocolaty

choco install urbackup-client -y




#check client install & set urbackup client settings
$urbackupcommand = 'c:\Program Files\Urbackup\UrbackupClient_cmd.exe'
$urbackupcommandargs = @('set-settings',
    '-k internet_mode_enabled -v true',
    '-k internet_server -v $urbackupserver',
    '-k internet_server_port -v $urbackupport', 
    ' -k computername -v $urbackupcomputername',
    '-k internet_authkey -v $urbackupkey'
)
if (Test-Path $urbackupcommand) {
    & $urbackupcommand $urbackupcommandargs
    exit 0
}
else {
    Write-Output "UrBackup doesn't seem to be installed"
    exit 1
}
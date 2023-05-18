<#
    .SYNOPSIS
    Joins computer to Active Directory.

    .DESCRIPTION 
    Computer can be joined to AD in a specific OU specified in the parameters or it will join the default location.

    .PARAMETER domain
    The domain name to join the computer to.

    .PARAMETER password
    The password for the domain account.

    .PARAMETER UserAccount
    The user account to use for joining the domain.

    .PARAMETER OUPath
    The Organizational Unit (OU) to place the computer object in.
    
    .OUTPUTS
    Results are printed to the console and sent to a log file in C:\Temp

    .EXAMPLE
    In parameter set desired items
    -domain DOMAIN -password ADMINpassword -UserAccount ADMINaccount -OUPath OU=testOU,DC=test,DC=local


    .NOTES
    Change Log
    V1.0 Initial release 6/19/2021 rfost52
    V1.1 Parameterization; Error Checking with conditionals and exit codes
    V1.2 Variable declarations cleaned up; minor syntax corrections; Output to file added (@jeevis)
    V1.3 Fixed error with string to secure-string convertion; Added information for escaping $ character (@jxd-decision)

    Reference Links: 
    www.google.com
    docs.microsoft.com
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "The domain name to join the computer to.")]
    [ValidateNotNullOrEmpty()]
    [string]$Domain,

    [Parameter(Mandatory = $true, HelpMessage = "The password for the domain account. If the password contains a '$' you have to escape it with a single backtick '``'")]
    [ValidateNotNullOrEmpty()]
    [string]$Password,

    [Parameter(Mandatory = $true, HelpMessage = "The user account to use for joining the domain.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserAccount,

    [Parameter(HelpMessage = "The Organizational Unit (OU) to place the computer object in.")]
    [ValidateNotNullOrEmpty()]
    [string]$OUPath
)


if ([string]::IsNullOrEmpty($domain)) {
    Write-Output "Domain must be defined. Use -domain <value> to pass it."
    EXIT 1
}

if ([string]::IsNullOrEmpty($UserAccount)) {
    Write-Output "User Account must be defined. Use -UserAccount <value> to pass it."
    EXIT 1
}

if ([string]::IsNullOrEmpty($password)) {
    Write-Output "Password must be defined. Use -password <value> to pass it."
    EXIT 1
}

else {
    $username = "$domain\$UserAccount"
    $securePassword = ConvertTo-SecureString -string $password -asPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
}

try {

    if ([string]::IsNullOrEmpty($OUPath)) {
        Write-Output "OU Path is not defined. Computer object will be created in the default OU."
        Add-Computer -DomainName $domain -Credential $credential -Restart
        echo "Add-Computer -DomainName $domain -Credential $credential -Restart" >> C:\Temp\ADJoinCommand.log
        EXIT 0
    }

    else {
        Add-Computer -DomainName $domain -OUPath $OUPath -Credential $credential -Restart
        echo "Add-Computer -DomainName $domain -OUPath $OUPath -Credential $credential -Restart" >> C:\Temp\ADJoinCommand.log
        EXIT 0
    }
}

catch {
    Write-Output "An error has occured."
    EXIT 1
}

<#
.SYNOPSIS
    Trigger a remote wipe via MDM.

.DESCRIPTION
    Invokes the 'doWipeMethod' in Windows equivalent to the Reset function in the Settings app.

.NOTES
    v1.0 7/2024 bbrendon Initial version
#>

$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_RemoteWipe"
$methodName = "doWipeMethod"

$session = New-CimSession

$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
$params.Add($param)

try {
    $instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
    $session.InvokeMethod($namespaceName, $instance, $methodName, $params)
}
catch [Exception] {
    write-host $_ | out-string
}

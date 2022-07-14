$serviceName = "HuntressAgent"
$tls = "Tls12";
[System.Net.ServicePointManager]::SecurityProtocol = $tls;
If (Get-Service $serviceName -ErrorAction SilentlyContinue) {
    $service = Get-Service -Name $serviceName
    $stat = $service.Status
    exit 0
}
Else {
    exit 1
}

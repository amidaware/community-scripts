

function ConvertTo-ProductKey {
    param (
        [parameter(Mandatory = $True, Position = 0)]
        $Registry,
        [parameter()]
        [Switch]$x64
    )
    begin {
        $map = "BCDFGHJKMPQRTVWXY2346789"
    }
    process {
        $ProductKey = ""
        
        $prodkey = $Registry[0x34 .. 0x42]
        
        for ($i = 24; $i -ge 0; $i--) {
            $r = 0
            for ($j = 14; $j -ge 0; $j--) {
                $r = ($r * 256) -bxor $prodkey[$j]
                $prodkey[$j] = [math]::Floor([double]($r / 24))
                $r = $r % 24
            }
            $ProductKey = $map[$r] + $ProductKey
            if (($i % 5) -eq 0 -and $i -ne 0) {
                $ProductKey = "-" + $ProductKey
            }
        }
        $ProductKey
    }
}

$x = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -name DigitalProductId
$key = ConvertTo-ProductKey $x.DigitalProductId
Write-output($Key)
# Use to get the size of a folder, and it's sub-folders

# Parameter usage -Path 'c:\Program Files'

param ($Path = ".")

$ErrorActionPreference = 'silentlycontinue'

$PrettySizeColumn = @{name = "Size"; expression = {
        $size = $_.Size
        if ( $size -lt 1KB ) { $sizeOutput = "$("{0:N2}" -f $size) B" }
        ElseIf ( $size -lt 1MB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1KB)) KB" }
        ElseIf ( $size -lt 1GB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1MB)) MB" }
        ElseIf ( $size -lt 1TB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1GB)) GB" }
        ElseIf ( $size -lt 1PB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1TB)) TB" }
        ElseIf ( $size -ge 1PB ) { $sizeOutput = "$("{0:N2}" -f ($size / 1PB)) PB" } 
        $sizeOutput
    }
}

Get-ChildItem -Path $Path | Where-Object { $_.PSIsContainer } | ForEach-Object { 
    $size = ( Get-ChildItem -Path $_.FullName -Recurse -Force | where { !$_.PSIsContainer } | Measure-Object -Sum Length).Sum 
    $obj = new-object -TypeName psobject -Property @{
        Path = $_.Name
        Time = $_.LastWriteTime
        Size = $size
    }
    $obj  
} | Sort-Object -Property Size -Descending | Select-Object Path, $PrettySizeColumn


# Needs parameterization


$url = "https://www.example.com"
$icon = "C:\path\to\icon.ico"
$desktop = [Environment]::GetFolderPath("Desktop")
$shortcut = New-Object -comObject WScript.Shell
$link = $shortcut.CreateShortcut("$desktop\Example.lnk")
$link.TargetPath = $url
$link.IconLocation = $icon
$link.Save()
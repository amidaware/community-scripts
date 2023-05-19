# Basic Script to run manufacturer specific commands on devices


$oem = ((Get-WMIObject -class Win32_ComputerSystem).Manufacturer)

if ($oem -match 'Dell')
{
Write-Output "Its $oem Lets Run the Code"

# Add in Update commands here

}

elseif ($oem -match 'HP')
{
Write-Output "Its $oem Lets Run the Code"

# Add in Update commands here

}

elseif ($oem -match 'Lenovo')
{
Write-Output "Its $oem Lets Run the Code"

# Add in Update commands here

}

elseif ($oem -match 'Intel')
{
Write-Output "Its $oem Lets Run the Code"

# Add in Update commands here

}

elseif ($oem -match 'Dynabook')
{
Write-Output "Its $oem Lets Run the Code"

# Add in Update commands here

}

elseif ($oem -match 'Acer')
{
Write-Output "Its $oem Lets Run the Code"

# Add in Update commands here

}

elseif ($oem -match 'Asus')
{
Write-Output "Its $oem Lets Run the Code"

# Add in Update commands here

}

else
{
Write-Output "This machine is made by $oem which isnt supported"
}

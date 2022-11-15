$SerialNumber = (Get-WmiObject win32_bios | select Serialnumber).serialnumber
$value = @{Description = "$SerialNumber"}
Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property $value
Rename-Computer -NewName $SerialNumber -Restart
#List of Shares to copy
$DirectoryList = (Get-Content $env:SystemDrive:\Temp\Shares.txt)
#Date for logging
$date = Get-Date -Format yyyy_MM_dd
#First scheduled task time
$time = [System.DateTime] "23:20"
#Use Managed Service Account vs DA
$principal = New-ScheduledTaskPrincipal -UserId contoso\msaFileServer01$ -LogonType Password
#Limit 1 hour transfer window and highest priority
$taskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1) -Priority 0
#Loop through each directory to copy and offset each by 10 minutes
foreach ($Directory in $DirectoryList){
    $Source = "\\FileServer01\$Directory"
    $Destination = "\\FileServer02\$Directory"
    $action = New-ScheduledTaskAction -Execute robocopy.exe -Argument "$Source $Destination /e /zb /copyall /mt:24 /r:2 /w:1 /xo  /log+:C:\Scripts\Robocopy_$($Directory)_$Date.txt"
    $trigger = New-ScheduledTaskTrigger -at $($time.ToString("HH:mm")) -DaysOfWeek Monday,Wednesday,Friday -Weekly
    Register-ScheduledTask -TaskName "$Directory Robocopy" -Action $action -Trigger $trigger -Principal $principal -Settings $taskSettings
    $time = $time.AddMinutes(10)
}
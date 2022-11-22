$BaseCSV = import-csv "C:\Path\to\Test.csv"

$Startrow = 0
$Counter = 1
$Increment = 20

while ($startrow -lt $BaseCSV.count){
    $BaseCSV | Select-Object -Skip $Startrow -First $Increment | Export-Csv "C:\Path\to\Test_Split$($Counter).csv" -NoClobber -NoTypeInformation
    $Startrow += $Increment
    $Counter ++
}
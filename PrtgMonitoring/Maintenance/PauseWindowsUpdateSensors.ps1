if(!(Get-PrtgClient)){
    Write-Host("Please run first _Initialise-prtgapi") -ForegroundColor Red -BackgroundColor White
    Exit 1
}

$allUpdateSensors = get-sensor -Name "Windows Updates Status"
$productionSensors = $allUpdateSensors | Where-Object {$_.Group -like "AGIS-*"}
$nonProductionSensors = $allUpdateSensors | Where-Object {$_.Group -notlike "AGIS-*"}

$updateMonday = Get-Date -Year (Get-Date).Year -Month (Get-Date).Month -Day 8 -Hour 10 -Minute 0 -Second 0
if ((Get-Date) -gt $updateMonday){
    $updateMonday = $updateMonday.AddMonths(1)
}
while ($updateMonday.DayOfWeek -ne "Monday"){
    $updateMonday = $updateMonday.AddDays(1)
}
#$updateMonday = get-date -Year 2018 -Month 12 -Day 4
Write-Host ("Pausing {1} production-windows-update sensors until: {0}" -f $updateMonday, $productionSensors.length)
#$productionSensors | Pause-Object -Until $updateMonday 
# weird, normal piping no longer seems to work
$productionSensors | %{$_ | Suspend-Object -Until $updateMonday}
Write-Host ("Pausing {1} non-production-windows-update sensors until: {0}" -f $updateMonday.AddDays(-7), $nonProductionSensors.length)
$nonProductionSensors | %{$_ | Suspend-Object -Until ($updateMonday.AddDays(-7))}

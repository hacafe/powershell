Connect-VIServer -Server @@@servidor@@@

$allhosts = @()
$hosts = Get-VMHost

foreach($vmHost in $hosts){
$hoststat = “” | Select HostName, CORE, CPUCapacity, CPUUsed, CPUFree, RAM, MemoryUsed, MemoryFree, VersionVM, MemMax, MemAvg, MemMin, CPUMax, CPUAvg, CPUMin
$hoststat.HostName = $vmHost.name

# Get CPU and RAM
$hoststat.CORE = $vmHost.NumCpu
$hoststat.CPUCapacity = [math]::Round($vmHost.CpuTotalMhz/1000,2)
$hoststat.CPUUsed = [math]::Round($vmHost.CpuUsageMhz/1000,2)
$hoststat.CPUFree = [math]::Round(($vmHost.CpuTotalMhz - $vmHost.CpuUsageMhz)/1000,2)
$hoststat.RAM = [math]::Round($vmHost.MemoryTotalGB,0)
$hoststat.MemoryUsed = [math]::Round($vmHost.MemoryUsageGB,2)
$hoststat.MemoryFree = [math]::Round($vmHost.MemoryTotalGB-$vmHost.MemoryUsageGB,2)
$hoststat.VersionVM = $vmHost.Version

$statcpu = Get-Stat -Entity ($vmHost)-start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 10000 -stat cpu.usage.average
$statmem = Get-Stat -Entity ($vmHost)-start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 10000 -stat mem.usage.average

$cpu = $statcpu | Measure-Object -Property value -Average -Maximum -Minimum
$mem = $statmem | Measure-Object -Property value -Average -Maximum -Minimum

$hoststat.CPUMax = [math]::Round($cpu.Maximum, 2)
$hoststat.CPUAvg = [math]::Round($cpu.Average, 2)
$hoststat.CPUMin = [math]::Round($cpu.Minimum, 2)
$hoststat.MemMax = [math]::Round($mem.Maximum, 2)
$hoststat.MemAvg = [math]::Round($mem.Average, 2)
$hoststat.MemMin = [math]::Round($mem.Minimum, 2)

$allhosts += $hoststat
}

$allhosts | Select HostName, CORE, CPUCapacity, CPUUsed, CPUFree, RAM, MemoryUsed, MemoryFree, VersionVM, CPUAvg, MemAvg, MemMax, MemMin, CPUMax, CPUMin | Sort-Object -Property HostName | Export-Csv “C:\Users\xxxxx\data_host.csv” -noTypeInformation
Write-Host "Data successfully exported to 'C:\Users\xxxxx\data_host.csv'"

Disconnect-VIServer -Server @@@servidor@@@ -Confirm:$false

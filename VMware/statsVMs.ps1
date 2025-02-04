#Connect to vCenter Server using credentials
Connect-VIServer -Server @@@servidor@@@

# Get powered-on VMs
$vms = Get-Vm
#| Where-Object { $_.PowerState -eq "PoweredOn" }

# Function to collect VM statistics (reusable)
function Get-VMStats {
    param(
        [PSObject]$vm
    )

    $vmstat = New-Object PSObject -Property @{
        VmName = $vm.Name
	CPU = 0
	RAM = 0
        MemMax = 0
        MemAvg = 0
        MemMin = 0
        CPUMax = 0
        CPUAvg = 0
        CPUMin = 0
        DiskCapacity = 0
	FreeSpace = 0
        UsedSpace = 0
	ProvisionedDisk = 0
	UsedDisk = 0
    }

    # Get Core and RAM
    $vmstat.CPU = $vm.NumCpu
    $vmstat.RAM = $vm.MemoryGB

    # Get CPU and memory statistics
    $statcpu = Get-Stat -Entity $vm -start (get-date).AddDays(-31) -Finish (Get-Date) -MaxSamples 10000 -stat cpu.usage.average
    $statmem = Get-Stat -Entity $vm -start (get-date).AddDays(-31) -Finish (Get-Date) -MaxSamples 10000 -stat mem.usage.average

    $cpu = $statcpu | Measure-Object -Property value -Average -Maximum -Minimum
    $mem = $statmem | Measure-Object -Property value -Average -Maximum -Minimum

    $vmstat.CPUMax = [math]::Round($cpu.Maximum, 2)
    $vmstat.CPUAvg = [math]::Round($cpu.Average, 2)
    $vmstat.CPUMin = [math]::Round($cpu.Minimum, 2)
    $vmstat.MemMax = [math]::Round($mem.Maximum, 2)
    $vmstat.MemAvg = [math]::Round($mem.Average, 2)
    $vmstat.MemMin = [math]::Round($mem.Minimum, 2)

    # Get disk statistics
    $vmstat.DiskCapacity = [math]::Round(((Get-HardDisk $vm | Measure-Object CapacityGB -Sum).Sum),0)
    $vmstat.FreeSpace = [math]::Round(($vm.Guest.Disks | Measure-Object FreeSpaceGB -Sum | Select -ExpandProperty Sum),2)
    $vmstat.UsedSpace = ($vmstat.DiskCapacity)-($vmstat.FreeSpace)

    $vmstat.ProvisionedDisk = [math]::Round(($vm.ProvisionedSpaceGB),0)
    $vmstat.UsedDisk = [math]::Round(($vm.UsedSpaceGB),0)

    return $vmstat
}

# Collect statistics for each VM
$allVMs = @()
foreach ($vm in $vms) {
    $vmStats = Get-VMStats -vm $vm
    $allVMs += $vmStats
}

# Export data to CSV
$allVMs | Select VmName, CPU, RAM, DiskCapacity, CPUAvg, MemAvg, UsedSpace, FreeSpace, CPUMax, CPUMin, MemMax, MemMin, ProvisionedDisk, UsedDisk | Sort-Object -Property VmName | Export-Csv -Path "C:\Users\xxxxx\data_VMs.csv" -NoTypeInformation
Write-Host "Data successfully exported to 'C:\Users\xxxxx\data_VMs.csv'"

Disconnect-VIServer -Server @@@servidor@@@ -Confirm:$false

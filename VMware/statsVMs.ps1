<#
.FUNCTION
    VMware VM Performance Monthly Report
.DESCRIPTION
    Collects CPU, memory, and disk metrics for all VMs for the previous calendar month.
    Generates a CSV report with percentage-formatted averages.
.NOTES
    Author: hacafe
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

# REQUIREMENTS CHECK - Install VMware PowerCLI if missing
if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
    try {
        Write-Host "Installing VMware PowerCLI module..."
        Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force -ErrorAction Stop
        Import-Module VMware.PowerCLI -ErrorAction Stop
        Write-Host "Module installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install VMware PowerCLI: $_"
        exit 1
    }
}

# CONFIGURATION
$vCenterServer = "vcenter.medellin.gov.co"
$reportFolder = "C:\Users\a71363375\Documents\reports"
$reportName = "vmstatsHCI_$(Get-Date -Format 'yyyyMM').csv"

try {
    Write-Host "Connecting to vCenter server $vCenterServer..."
    Connect-VIServer -Server $vCenterServer -ErrorAction Stop
}
catch {
    Write-Error "Failed to connect to vCenter: $_"
    exit 1
}

# DATE CALCULATION - Previous month's exact dates
$currentDate = Get-Date
$firstDayOfLastMonth = $currentDate.AddMonths(-1).Date.AddDays(-($currentDate.Day - 1))
$lastDayOfLastMonth = $currentDate.AddDays(-$currentDate.Day)  # Last day of previous month
$monthName = $firstDayOfLastMonth.ToString("MMMyyyy")

Write-Host "Collecting VM data for period: $($firstDayOfLastMonth.ToShortDateString()) to $($lastDayOfLastMonth.ToShortDateString())"

# CREATE REPORTS DIRECTORY IF NOT EXISTS
if (-not (Test-Path -Path $reportFolder)) {
    New-Item -Path $reportFolder -ItemType Directory -Force | Out-Null
}

# DATA COLLECTION
$allVMs = @()
$vms = Get-VM

foreach ($vm in $vms) {
    try {
        Write-Host "Processing VM: $($vm.Name)" -ForegroundColor Cyan
        
        # Initialize VM stats with optimized properties
        $vmstat = [PSCustomObject]@{
            VMName = $vm.Name
            PowerState = $vm.PowerState
            VMStatus = "OK"
            # OS Information
            OS = $vm.Guest.OSFullName
            VMwareToolsStatus = $vm.ExtensionData.Guest.ToolsStatus
	    # Basic Configuration
            CPU = $vm.NumCpu
            RAM = $vm.MemoryGB
            # Disk Information
            DiskCapacity = "N/A"
            FreeSpace = "N/A"
            UsedSpace = "N/A"
            ProvisionedDisk = "N/A"
            UsedDisk = "N/A"
            # Performance Metrics
            CPUMax = "N/A"
            CPUAvg = "N/A"
            CPUMin = "N/A"
            MemMax = "N/A"
            MemAvg = "N/A"
            MemMin = "N/A"
            # Additional Info
            HostName = $vm.VMHost.Name
            Cluster = $vm.VMHost.Parent.Name
            Folder = $vm.Folder.Name
            Notes = ""
        }

        # Skip powered-off VMs for performance stats
        if ($vm.PowerState -ne "PoweredOn") {
            $vmstat.VMStatus = "Skipped - PoweredOff"
            $vmstat.Notes = "Performance stats not available"
            $allVMs += $vmstat
            continue
        }

        # Disk information collection
        try {
            $hardDisks = Get-HardDisk -VM $vm -ErrorAction SilentlyContinue
            if ($hardDisks) {
                $vmstat.DiskCapacity = [math]::Round(($hardDisks | Measure-Object CapacityGB -Sum).Sum, 0)
                $vmstat.ProvisionedDisk = [math]::Round($vm.ProvisionedSpaceGB, 0)
                $vmstat.UsedDisk = [math]::Round($vm.UsedSpaceGB, 0)
                
                if ($vm.Guest.Disks) {
                    $vmstat.FreeSpace = [math]::Round(($vm.Guest.Disks | Measure-Object FreeSpaceGB -Sum).Sum, 2)
                    $vmstat.UsedSpace = $vmstat.DiskCapacity - $vmstat.FreeSpace
                } else {
                    $vmstat.Notes += " | No guest disk info"
                }
            }
        } catch {
            $vmstat.VMStatus = "PartialData"
            $vmstat.Notes += " | DiskError: $_"
        }

        # Performance metrics collection
        try {
            $statcpu = Get-Stat -Entity $vm -Start $firstDayOfLastMonth -Finish $lastDayOfLastMonth `
                       -MaxSamples 10000 -Stat cpu.usage.average -ErrorAction SilentlyContinue
            if ($statcpu) {
                $cpuStats = $statcpu | Measure-Object -Property value -Average -Maximum -Minimum
                $vmstat.CPUMax = [math]::Round($cpuStats.Maximum, 2)
                $vmstat.CPUAvg = "{0}%" -f [math]::Round($cpuStats.Average, 2)
                $vmstat.CPUMin = [math]::Round($cpuStats.Minimum, 2)
            } else {
                $vmstat.Notes += " | NoCPUData"
            }
        } catch {
            $vmstat.VMStatus = "PartialData"
            $vmstat.Notes += " | CPUError: $_"
        }

        try {
            $statmem = Get-Stat -Entity $vm -Start $firstDayOfLastMonth -Finish $lastDayOfLastMonth `
                       -MaxSamples 10000 -Stat mem.usage.average -ErrorAction SilentlyContinue
            if ($statmem) {
                $memStats = $statmem | Measure-Object -Property value -Average -Maximum -Minimum
                $vmstat.MemMax = [math]::Round($memStats.Maximum, 2)
                $vmstat.MemAvg = "{0}%" -f [math]::Round($memStats.Average, 2)
                $vmstat.MemMin = [math]::Round($memStats.Minimum, 2)
            } else {
                $vmstat.Notes += " | NoMemData"
            }
        } catch {
            $vmstat.VMStatus = "PartialData"
            $vmstat.Notes += " | MemError: $_"
        }

        # Clean up notes if no issues
        if ($vmstat.Notes -eq "") {
            $vmstat.PSObject.Properties.Remove('Notes')
        }

        $allVMs += $vmstat
    }
    catch {
        Write-Warning "Critical error processing VM $($vm.Name): $_"
        $allVMs += [PSCustomObject]@{
            VMName = $vm.Name
            VMStatus = "CriticalError"
            Notes = "Processing failed: $_"
        }
    }
}

# EXPORT RESULTS
$csvPath = Join-Path -Path $reportFolder -ChildPath $reportName

try {
    $allVMs | Sort-Object VMName | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "VM report successfully generated: $csvPath" -ForegroundColor Green
    Write-Host "Total VMs processed: $($vms.Count)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to export VM report: $_"
}

# CLEANUP
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
Write-Host "Disconnected from vCenter server" -ForegroundColor Yellow

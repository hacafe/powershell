<#
.FUNCTION
    VMware Host Performance Monthly Report
.DESCRIPTION
    Collects CPU and memory metrics for all VMware hosts for the previous calendar month.
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

# VCENTER CONNECTION
$vCenterServer = "name_server"
$reportFolder = "path"

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

Write-Host "Collecting data for period: $($firstDayOfLastMonth.ToShortDateString()) to $($lastDayOfLastMonth.ToShortDateString())"

# CREATE REPORTS DIRECTORY IF NOT EXISTS
if (-not (Test-Path -Path $reportFolder)) {
    New-Item -Path $reportFolder -ItemType Directory -Force | Out-Null
}

# DATA COLLECTION AND TRANSFORM
$allhosts = @()
$hosts = Get-VMHost

foreach ($vmHost in $hosts) {
    try {
        # Initialize host object with all properties
        $hoststat = [PSCustomObject]@{
            HostName      = $vmHost.name
            CORE          = $vmHost.NumCpu
            CPUCapacity   = [math]::Round($vmHost.CpuTotalMhz/1000, 2)
            CPUUsed       = [math]::Round($vmHost.CpuUsageMhz/1000, 2)
            CPUFree       = [math]::Round(($vmHost.CpuTotalMhz - $vmHost.CpuUsageMhz)/1000, 2)
            RAM           = [math]::Round($vmHost.MemoryTotalGB, 0)
            MemoryUsed    = [math]::Round($vmHost.MemoryUsageGB, 2)
            MemoryFree    = [math]::Round($vmHost.MemoryTotalGB - $vmHost.MemoryUsageGB, 2)
            VersionVM     = $vmHost.Version
        }

        # Get performance statistics for previous month
        $statcpu = Get-Stat -Entity $vmHost -Start $firstDayOfLastMonth -Finish $lastDayOfLastMonth `
                   -MaxSamples 10000 -Stat cpu.usage.average -ErrorAction Stop
        
        $statmem = Get-Stat -Entity $vmHost -Start $firstDayOfLastMonth -Finish $lastDayOfLastMonth `
                   -MaxSamples 10000 -Stat mem.usage.average -ErrorAction Stop

        # Calculate metrics
        $cpuStats = $statcpu | Measure-Object -Property value -Average -Maximum -Minimum
        $memStats = $statmem | Measure-Object -Property value -Average -Maximum -Minimum

        # Add performance metrics with percentage formatting for averages
        $hoststat | Add-Member -NotePropertyName "CPUMax" -NotePropertyValue ([math]::Round($cpuStats.Maximum, 2))
        $hoststat | Add-Member -NotePropertyName "CPUAvg" -NotePropertyValue ("{0}%" -f [math]::Round($cpuStats.Average, 2))
        $hoststat | Add-Member -NotePropertyName "CPUMin" -NotePropertyValue ([math]::Round($cpuStats.Minimum, 2))
        $hoststat | Add-Member -NotePropertyName "MemMax" -NotePropertyValue ([math]::Round($memStats.Maximum, 2))
        $hoststat | Add-Member -NotePropertyName "MemAvg" -NotePropertyValue ("{0}%" -f [math]::Round($memStats.Average, 2))
        $hoststat | Add-Member -NotePropertyName "MemMin" -NotePropertyValue ([math]::Round($memStats.Minimum, 2))

        $allhosts += $hoststat
        Write-Host "Collected data for host: $($vmHost.Name)" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Error processing host $($vmHost.Name): $_"
        # Create minimal host record with error indication
        $allhosts += [PSCustomObject]@{
            HostName      = $vmHost.name
            Error         = "Data collection failed"
        }
    }
}

# EXPORT RESULTS
$csvPath = Join-Path -Path $reportFolder -ChildPath "hoststats_$monthName.csv"

try {
    $allhosts | Sort-Object HostName | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report successfully generated: $csvPath" -ForegroundColor Green
    
    # Optional: Open the report folder
    # Start-Process $reportFolder
}
catch {
    Write-Error "Failed to export report: $_"
}

# CLEANUP
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
Write-Host "Disconnected from vCenter server" -ForegroundColor Yellow

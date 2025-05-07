<#
.FUNCTION
    VMware Datastore Capacity Monthly Report
.DESCRIPTION
    Collects capacity metrics for all VMware datastores as of last month.
    Generates a CSV report with storage usage percentages including % symbol.
.NOTES
    Author: hacafe
    Date: $(Get-Date -Format "yyyy-MM-dd")
#>

# REQUIREMENTS CHECK
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
$vCenterServer = "host"
$reportFolder = "C:\path\reports"

# Calculate reporting period (last month)
$reportDate = (Get-Date).AddMonths(-1)
$monthName = $reportDate.ToString("yyyyMM")
$reportName = "storestatsHCI_$monthName.csv"

try {
    # CONNECT TO VCENTER
    Write-Host "Connecting to vCenter server..."
    Connect-VIServer -Server $vCenterServer -ErrorAction Stop
    
    # ENSURE REPORT DIRECTORY EXISTS
    if (-not (Test-Path -Path $reportFolder)) {
        New-Item -Path $reportFolder -ItemType Directory -Force | Out-Null
    }

    # COLLECT DATA
    Write-Host "Collecting last month's datastore data ($monthName)..."
    $reportData = @()
    $datastores = Get-Datastore
    
    foreach ($ds in $datastores) {
        Write-Host "Processing datastore: $($ds.Name)" -ForegroundColor Cyan
        try {
            $usedPerc = [math]::Round((($ds.CapacityGB - $ds.FreeSpaceGB) / $ds.CapacityGB) * 100, 2)
            
            $reportData += [PSCustomObject]@{
                Name          = $ds.Name
                Type          = $ds.Type
                CapacityGB    = [math]::Round($ds.CapacityGB, 2)
                FreeSpaceGB   = [math]::Round($ds.FreeSpaceGB, 2)
                UsedSpaceGB   = [math]::Round(($ds.CapacityGB - $ds.FreeSpaceGB), 2)
                SpaceUsedPerc = "$usedPerc%"
                Status        = "OK"
            }
        }
        catch {
            Write-Warning "Error processing datastore $($ds.Name): $_"
            $reportData += [PSCustomObject]@{
                Name   = $ds.Name
                Status = "Error: $_"
            }
        }
    }

    # EXPORT REPORT
    $reportPath = Join-Path -Path $reportFolder -ChildPath $reportName
    $reportData | Sort-Object Name | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Last month's report ($monthName) generated: $reportPath" -ForegroundColor Green
    Write-Host "Total datastores processed: $($datastores.Count)" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}
finally {
    # CLEANUP CONNECTION
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Disconnected from vCenter server" -ForegroundColor Yellow
    }
}

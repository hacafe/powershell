Connect-VIServer -Server @@@servidor@@@

$allhosts = @()
$stores = Get-Datastore 

foreach($store in $stores){
$storestat = “” | Select Name, CapacityGB, FreeSpaceGB, SpaceUsedPorc
$storestat.Name = $store.name

# Get Data
$storestat.CapacityGB = [math]::Round(($store.CapacityGB),2)
$storestat.FreeSpaceGB = [math]::Round(($store.FreeSpaceGB),2)
$storestat.SpaceUsedPorc = [math]::Round((($store.CapacityGB - $store.FreeSpaceGB)/$store.CapacityGB)*100,2)

$allhosts += $storestat
}

$allhosts | Select Name, CapacityGB, FreeSpaceGB, SpaceUsedPorc | Sort-Object -Property Name | Export-Csv “C:\Users\xxxxx\data_store.csv” -noTypeInformation
Write-Host "Data successfully exported to 'C:\Users\xxxxx\data_store.csv'"

Disconnect-VIServer -Server @@@servidor@@@ -Confirm:$false

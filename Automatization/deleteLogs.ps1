$RutaBase = "C:\IXL\Logs"
$FechaLimite = (Get-Date).AddDays(-10)

Get-ChildItem -Path $RutaBase -File -Filter "*.log" -Recurse |
    Where-Object { $_.LastWriteTime -lt $FechaLimite } |
    Remove-Item -Force

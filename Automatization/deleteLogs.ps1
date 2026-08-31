$RutaBase = "L:\IISLogs"
$FechaLimite = (Get-Date).AddDays(-15)

Get-ChildItem -Path $RutaBase -Directory -Filter "W3SVC*" |
    ForEach-Object {
        Get-ChildItem -Path $_.FullName -File -Filter "*.log" -Recurse |
            Where-Object { $_.LastWriteTime -lt $FechaLimite } |
            Remove-Item -Force
    }

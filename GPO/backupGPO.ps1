###Backup GPO
function BackupGPO {
    # Captura la fecha actual y crea el directorio
    $fecha = Get-Date -Format "ddMMMyyyy"
    $directorio = "C:\BackupGPO\$fecha"

    # Verifica si la carpeta ya existe, si no, la crea
    if (-Not (Test-Path -Path $directorio)) {
        New-Item -Path $directorio -ItemType Directory -Force
    }

    # Ejecuta el comando Backup-GPO
    Backup-GPO -All -Path $directorio

    # Define la fecha límite: tres meses antes de la fecha actual
    $limiteFecha = (Get-Date).AddMonths(-3)

    # Obtiene todos los directorios dentro de C:\BackupGPO que sean más viejos que la fecha límite
    $backups = Get-ChildItem -Path "C:\BackupGPO" | Where-Object {
        $_.PSIsContainer -and $_.CreationTime -lt $limiteFecha
    }

    # Elimina cada directorio que cumple la condición
    foreach ($backup in $backups) {
        Remove-Item -Path $backup.FullName -Recurse -Force
    }
}
# Llama a la función
BackupGPO

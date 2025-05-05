### Backup GPO Function
function BackupGPO {
    # Get current date and create backup directory path (format: "05May2025")
    $date = Get-Date -Format "ddMMMyyyy"
    $directory = "C:\BackupGPO\$date"

    # Check if directory exists, create it if missing
    if (-Not (Test-Path -Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force
    }

    # Backup ALL Group Policy Objects to the created directory
    Backup-GPO -All -Path $directory

    # Calculate cutoff date (3 months ago from today)
    $oldBackup = (Get-Date).AddMonths(-3)

    # Find all subfolders in C:\BackupGPO older than 3 months
    $backups = Get-ChildItem -Path "C:\BackupGPO" | Where-Object {
        $_.PSIsContainer -and $_.CreationTime -lt $oldBackup
    }

    # Delete outdated backup folders (older than 3 months)
    foreach ($backup in $backups) {
        Remove-Item -Path $backup.FullName -Recurse -Force
    }
}

# Execute the BackupGPO function
BackupGPO

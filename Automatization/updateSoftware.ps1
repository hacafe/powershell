<#
.SYNOPSIS
    Remotely installs Java on a list of computers.

.DESCRIPTION
    This script takes a list of computer names from a file and remotely installs Java
    using the installer located on a network share.  It assumes that the user running
    the script has administrative privileges on the target computers and that the
    network share is accessible to those computers and WinRM service is UP (GPO).

.PARAMETER ComputerListName
    The name of a text file containing a list of computer names (one per line).
    This parameter is MANDATORY.

.PARAMETER JavaInstallerPath
    The network path to the Java installer executable.
    This parameter is MANDATORY.

.EXAMPLE
    # Installs Java on computers listed in servers.txt
    Install-Java -ComputerListName "C:\machines.txt" -JavaInstallerPath "\\server\repository\java8u451.exe"

.ARGUMENTS
    # Silently install
    /s apply to java installer, but the argument can be different to other applications

.INPUTS
    None.

.OUTPUTS
    None.  The script writes progress and error messages to the console.

.NOTES
    -  Requires PowerShell remoting to be enabled on the target computers (WinRM).
    -  The script must be run as a user with sufficient privileges on the target computers.
    -  The network share containing the Java installer must be accessible to the target computers.
    -  This script uses the /s switch for silent installation.  Ensure that the Java installer supports this switch.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerListName
)

begin {
    try {
        $Computers = Get-Content -Path $ComputerListName -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to read computer list: $($_.Exception.Message)"
        exit
    }
}

process {
    $InstallerPath = "\\path\java8u451.exe"
    $LocalInstallerPath = "C:\Windows\Temp\java8u451.exe"  # Destination on remote machines

    foreach ($Computer in $Computers) {
        if ([string]::IsNullOrWhiteSpace($Computer)) {
            Write-Warning "Skipping empty computer name."
            continue
        }

        Write-Verbose "Processing $Computer..."

        try {
            # Step 1: Check if Java 1.8 (any version) exists
            $JavaExists = Invoke-Command -ComputerName $Computer -ScriptBlock {
                return (Test-Path "C:\Program Files\Java\jre1.8*")
            } -ErrorAction Stop

            if (-not $JavaExists) {
                Write-Host "[REVIEW NEEDED] Java 1.8 NOT found on $Computer. Skipping installation." -ForegroundColor Red
                continue  # Skip to the next computer
            }
            else {
                Write-Host "Java 1.8 detected on $Computer. Proceeding with update..." -ForegroundColor Green
            }

            # Step 2: Copy the installer to the remote machine
            Copy-Item -Path $InstallerPath -Destination "\\$Computer\C$\Windows\Temp\" -Force -ErrorAction Stop

            # Step 3: Run the installer silently and delete it afterward
            Invoke-Command -ComputerName $Computer -ScriptBlock {
                param($LocalInstallerPath)
                Start-Process -FilePath $LocalInstallerPath -ArgumentList "/s" -Wait
                Write-Host "Java updated successfully on $($env:COMPUTERNAME)" -ForegroundColor Green
                Remove-Item -Path $LocalInstallerPath -Force -ErrorAction SilentlyContinue
            } -ArgumentList $LocalInstallerPath -ErrorAction Stop

            Write-Host "Success: Java updated on $Computer" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed on $Computer`: $($_.Exception.Message)"
        }
    }
}

end {
    Write-Host "Script completed. Review machines marked with '[REVIEW NEEDED]'." -ForegroundColor Cyan
}

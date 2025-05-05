<#
.FUNCTION
    Remotely disables SMB1 and Telnet Server and enable SMB2, on a list of computers.

.DESCRIPTION
    This script takes a list of computer names from a file and remotely executes commands to:
    - Disable SMB1 server-side configurations.
    - Disable the Telnet Server Windows feature.
    - Enable SMB2 server-side configurations.
    - Set registry values to further disable SMB1 and SMB2.

.PARAMETER ComputerListName
    The name of a text file containing a list of computer names (one per line).
    This parameter is now MANDATORY.

.EXAMPLE
    # Run on computers listed in C:\path\to\machines.txt using your own credentials
    .\disableSMB.ps1 -ComputerListName "C:\path\to\machines.txt"

.INPUTS
    None.

.OUTPUTS
    None.  The script writes progress and error messages to the console.

.NOTES
    - Requires PowerShell remoting to be enabled on the target computers (WinRM).
    - The script must be run as a user with sufficient privileges on the target computers.
    - Disabling SMB1 can have compatibility implications with older systems. SMB2 disabling is unusual and may have broader impacts.
    - Optional enable SMB3 on modern operative systems
    - The script includes error handling to gracefully handle offline computers or access denied errors.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerListName
)

begin
    {
    #  Load the list of computers from the file.
    try
        {
        $Computers = Get-Content -Path $ComputerListName -ErrorAction Stop
        }
    catch
        {
        Write-Error "Failed to read computer list from '$ComputerListName': $($_.Exception.Message)"
        exit  # Terminate the script if the file cannot be read.
        }
    }

process
    {
    #  Iterate through each computer in the list.
    foreach ($Computer in $Computers)
        {
        #  Check if the computer name is empty or whitespace.
        if ([string]::IsNullOrWhiteSpace($Computer))
            {
            Write-Warning "Skipping empty computer name."
            continue  # Go to the next computer in the loop.
        }
        Write-Verbose "Processing computer: $Computer"

        #  Define the commands to be executed remotely.
        $ScriptBlock = {
            #  Inside the ScriptBlock, $using: variables are used to access variables
            #  from the script's scope.

            # Disable SMB1 and enable SMB2 Server Configuration
            Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
            Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force
            #Set-SmbServerConfiguration -EnableSMB3Protocol $true -Force

            # Disable SMB1 Client Feature (Optional, usually client only)
            Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

            # Remove Telnet Server Feature
            Remove-WindowsFeature Telnet-Server -ErrorAction SilentlyContinue -WarningAction SilentlyContinue # common on servers, remove.

            # Set Registry Values for SMB1 and SMB2 (more definitive)
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0 -Force
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB2" -Value 1 -Force
            #Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB3" -Value 1 -Force

            # Write output to the console on the remote machine
            Write-Host "SMB1, SMB2 and Telnet configuration applied on $($env:COMPUTERNAME)"
        }  # End of ScriptBlock

        #  Execute the commands on the remote computer.
        try
            {
            Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlock -ErrorAction Stop
            Write-Host "Successfully configured $Computer" -ForegroundColor Green
        }
        catch
            {
            #  Handle errors that occur during the remote command execution.
            Write-Warning "Failed to configure $($Computer): $($_.Exception.Message)"
            #  Write-Error "Detailed error: $($Error | Format-List -Force)" #Uncomment for very detailed error.
        }
        } # End foreach
    } # End Process
end
    {
    Write-Host "Script completed."
    }

# https://www.spice-space.org/download.html


cd c:\windows\temp
$previousProtocol = [Net.ServicePointManager]::SecurityProtocol
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -ErrorAction Stop `
        -Uri 'https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe' `
        -OutFile 'spice-guest-tools-latest.exe'
} catch {
    Write-Warning "Skipping SPICE guest tools: $_"
    return
} finally {
    [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
}


# Needs to run the installer as SYSTEM to avoid the driver approval prompt.
#.\spice-guest-tools-latest.exe /S

Import-Module ScheduledTasks;
$name = "RunAs_LocalSystem_$([guid]::NewGuid())";
$actionArguments = @{
    '-Execute' = 'C:/Windows/Temp/spice-guest-tools-latest.exe';
    '-Argument' = '/S';
};
$action = New-ScheduledTaskAction @actionArguments;
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType Interactive;
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Start-ScheduledTask;
Unregister-ScheduledTask $name -Confirm:$false


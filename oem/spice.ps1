# https://www.spice-space.org/download.html


cd c:\windows\temp
# TODO curl might be unavailable in old PS versions
curl https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe -o spice-guest-tools-latest.exe


# Needs to run the installer as SYSTEM to avoid the driver approval prompt.
#.\spice-guest-tools-latest.exe /S

Import-Module ScheduledTasks;
$name = "RunAs_LocalSystem_$(New-Guid)";
$actionArguments = @{
    '-Execute' = 'C:/Windows/Temp/spice-guest-tools-latest.exe';
    '-Argument' = '/S';
};
$action = New-ScheduledTaskAction @actionArguments;
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType Interactive;
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Start-ScheduledTask;
Unregister-ScheduledTask $name -Confirm:$false


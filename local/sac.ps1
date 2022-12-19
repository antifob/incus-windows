# https://jdhitsolutions.com/blog/powershell-7/7969/deploy-openssh-server-to-windows-10/

if (get-windowscapability -online -name windows.desktop.ems-sac.tools* | ? state -like notpresent*) {
	$t = new-scheduledtasktrigger -At 23:59 -Once
	$u = New-scheduledtaskprincipal System
	$a = new-scheduledtaskaction -execute "powershell" -argument '-noprofile -command "& { Get-WindowsCapability -online -name windows.desktop.ems-sac.tools* | Add-WindowsCapability -online}"'
	$k = register-scheduledtask -taskpath \ -taskname "AddTask" -trigger $t -principal $u -action $a
	start-scheduledtask -taskname AddTask

	while (get-windowscapability -online -name windows.desktop.ems-sac.tools* | ? state -like notpresent*) {
		start-sleep -seconds 120
	}

	$k | unregister-scheduledtask -confirm:$false
}

cmd /c "%systemroot%\system32\bcdedit /ems on"
cmd /c "%systemroot%\system32\bcdedit /bootems on"
cmd /c "%systemroot%\system32\bcdedit /emssettings emsbaudrate:9600 emsport:1"

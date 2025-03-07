#
# https://stackoverflow.com/questions/8533860/net-framework-4-installation-in-silent-mode
# https://social.technet.microsoft.com/Forums/WINDOWS/en-US/f6763d33-ad34-4167-8879-ebdab96eb792/install-windows-management-framework-3-powershell-remotely-to-2008-r2?forum=winserverManagement
#

get-wmiobject win32_logicaldisk | % {
	if ($_.volumename -like 'STUFF*') {
		start-process ($_.deviceid+'/OEM/dotNetFx40_Full_x86_x64.exe') -wait -argumentlist '/q /norestart'
		start-process wusa.exe -wait -argumentlist ($_.deviceid+'/OEM/Windows6.1-KB2506143-x64.msu /quiet')
	}
}

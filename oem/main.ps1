get-wmiobject win32_logicaldisk | % {
        if ($_.volumename -like 'STUFF*') {
		$setupdrive = $_.deviceid
	}
}

cmd.exe /c "${setupdrive}\OEM\compile-dotnet-assemblies.bat"
reg.exe add "HKLM\System\CurrentControlSet\Control\Network\NewNetworkWindowOff"

. "${setupdrive}\OEM\power.ps1"
. "${setupdrive}\OEM\qemu-ga.ps1"
# . "${setupdrive}\OEM\sac.ps1"
. "${setupdrive}\OEM\ConfigureRemotingForAnsible.ps1"

if (test-path "${setupdrive}\local\main.ps1") {
	. "${setupdrive}\local\main.ps1"
}

cmd.exe /c "${setupdrive}\OEM\sysprep.bat" "${setupdrive}\OEM\unattend.xml"

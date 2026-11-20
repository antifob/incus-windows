param([string]$WinREDriver, [string]$LegacyWinREDriver)

get-wmiobject win32_logicaldisk | % {
        if ($_.volumename -like 'STUFF*') {
		$setupdrive = $_.deviceid
	}
}

if ($WinREDriver) {
	# Setup's storage driver is not carried into the recovery image.
	$mount = "$env:TEMP\incus-winre"
	New-Item -ItemType Directory -Path $mount -ErrorAction Stop | Out-Null
	reagentc.exe /mountre /path $mount
	if ($LASTEXITCODE) { throw "Cannot mount WinRE: $LASTEXITCODE" }
	$action = '/discard'
	try {
		Add-WindowsDriver -Path $mount -Driver "${setupdrive}\$WinREDriver" -ErrorAction Stop | Out-Null
		$action = '/commit'
	} finally {
		dism.exe /Unmount-Image "/MountDir:$mount" $action
		if ($LASTEXITCODE) { throw "Cannot unmount WinRE ($action): $LASTEXITCODE" }
		Remove-Item -LiteralPath $mount -ErrorAction Stop
	}
}

cmd.exe /c "${setupdrive}\OEM\compile-dotnet-assemblies.bat"
reg.exe add "HKLM\System\CurrentControlSet\Control\Network\NewNetworkWindowOff"

$agentdrive = Get-WmiObject -Class Win32_Volume | Where-Object { $_.Label -eq "incus-agent" }
if ($agentdrive -and (Test-Path -Path "$($agentdrive.Name)install.ps1")) {
	. "$($agentdrive.Name)install.ps1"
}

. "${setupdrive}\OEM\power.ps1"
. "${setupdrive}\OEM\qemu-ga.ps1" # QEMU guest-agent
start-sleep 30
. "${setupdrive}\OEM\spice.ps1" # copy-paste
start-sleep 30
# . "${setupdrive}\OEM\sac.ps1"
. "${setupdrive}\OEM\ConfigureRemotingForAnsible.ps1"

if (test-path "${setupdrive}\local\main.ps1") {
	. "${setupdrive}\local\main.ps1"
}

cmd.exe /c "${setupdrive}\OEM\sysprep.bat" "${setupdrive}\OEM\unattend.xml" $LegacyWinREDriver

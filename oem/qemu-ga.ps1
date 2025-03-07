#
# get-volume is only available from ps 4.0
# https://stackoverflow.com/questions/26168371/powershell-3-0-alternative-to-get-volume
#
#Start-Process msiexec.exe -Wait -ArgumentList ('/I '+((get-volume | ? filesystemlabel -like STUFF*).DriveLetter)+':\guest-agent\qemu-ga-x86_64.msi /quiet')
#Start-Process msiexec.exe -Wait -ArgumentList ('/I '+((get-volume | ? filesystemlabel -like STUFF*).DriveLetter)+':\virtio-win-gt-x64.msi /quiet')

get-wmiobject win32_logicaldisk | % {
	if ($_.volumename -like 'STUFF*') {
		Start-Process msiexec.exe -Wait -ArgumentList ('/I '+$_.deviceid+'\guest-agent\qemu-ga-x86_64.msi /quiet')
		Start-Process msiexec.exe -Wait -ArgumentList ('/I '+$_.deviceid+'\virtio-win-gt-x64.msi /quiet')
	}
}

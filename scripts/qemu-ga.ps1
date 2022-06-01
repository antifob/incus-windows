Start-Process msiexec.exe -Wait -ArgumentList ('/I '+((get-volume | ? filesystemlabel -like packer*).DriveLetter)+':\guest-agent\qemu-ga-x86_64.msi /quiet')

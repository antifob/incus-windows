Start-Process msiexec.exe -Wait -ArgumentList ('/I '+((get-volume | ? filesystemlabel -like packer*).DriveLetter)+':\guest-agent\qemu-ga-x86_64.msi /quiet')
Start-Process msiexec.exe -Wait -ArgumentList ('/I '+((get-volume | ? filesystemlabel -like packer*).DriveLetter)+':\virtio-win-gt-x64.msi /quiet')

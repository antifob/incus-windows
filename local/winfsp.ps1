echo "Enable the VirtIO File System Service"
$serviceName = 'VirtioFsSvc'
Set-Service -Name $serviceName -StartupType 'Automatic'
Start-Service -Name $serviceName

echo "Download and install WinFSP"
Invoke-WebRequest -Uri 'https://github.com/winfsp/winfsp/releases/download/v2.0/winfsp-2.0.23075.msi' -OutFile 'C:\winfsp-2.0.23075.msi'
Start-Process 'C:\winfsp-2.0.23075.msi' -ArgumentList '/passive' -Wait


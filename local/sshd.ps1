echo "Install OpenSSH Server"
$feature = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Server*" }

Write-Host "Add Feature: $($feature.Name)"
Add-WindowsCapability -Online -Name $feature.Name

echo "Set the SSHD service to start automatically"
Set-Service -Name sshd -StartupType 'Automatic'

echo "Configure the firewall to allow SSH traffic"
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

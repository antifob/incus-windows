echo "Install OpenSSH Server if not already installed"
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

echo "Set the SSHD service to start automatically"
Set-Service -Name sshd -StartupType 'Automatic'

echo "Configure the firewall to allow SSH traffic"
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

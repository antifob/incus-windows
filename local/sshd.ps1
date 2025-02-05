# Install OpenSSH Server if not already installed
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the SSHD service
Start-Service sshd

# Set the SSHD service to start automatically
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the SSHD service is running
Get-Service -Name sshd

# Optionally, configure the firewall to allow SSH traffic
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

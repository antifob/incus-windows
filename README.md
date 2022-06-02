# Windows VMs imaging

An LXD-oriented Windows VMs imaging tools.


## Features

- Supports cloud-init style configuration via Cloudbase-init.
- Supports serial console access (`lxc console $vm`).
- Supports WinRM access.
- High-performance power configuration.
- Most/all drivers installed.


## Requirements

- packer
- xorriso


## Usage

If your `/tmp` directory is small, you may use another directory by
setting the `TMPDIR` environment variable.

```
# Build the disk and LXD image metadata in ./output/win2022
sh ./tools/build.sh 2022

# Import into LXD
sh ./tools/import.sh ./output/win2022

# Create and launch the virtual machine
lxc init --vm win2022 w22 -c security.secureboot=false

# Prepare a script to run on boot
printf '#ps1\nnew-item c:/0000\n' | lxc config set w22 cloud-init.user-data -
lxc config device add w22 cidata disk source=cloud-init:config

# Start the VM
lxc start w22
```

All systems have an administrator-level account named `usr` with
password `changeme`. Additionally, the EMS/SAC service is installed;
allowing serial console access to the system:

```
lxc console w22
SAC> cmd
SAC> ch -si 1
Username: usr
Domain:
Password: changeme
C:\Windows\System32>
```


## References

https://github.com/ruzickap/packer-templates

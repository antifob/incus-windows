# Windows VMs imaging

An Incus-oriented Windows VMs imaging toolset.


## Features

- Custom/local ISO support.
- WinRM access (Ansible-ready).
- High-performance power configuration.
- Incus agent installed (except 2008 and 2012).
- Most/all drivers installed.
- Serial console access (disabled by default).


## Supported versions

The following Windows versions are supported.

- Windows 11 Enterprise (24H2)
- Windows 10 Enterprise (20H2, 21H2, 22H2)
- Windows Server 2025
- Windows Server 2022
- Windows Server 2019
- Windows Server 2016
- Windows Server 2012
- Windows Server 2008 R2 SP1


## Requirements

- curl
- incus
- python
- xorriso

```
apt-get --install-recommends install curl python3 xorriso

# in case Incus is not installed already
curl -fsSL https://pkgs.zabbly.com/get/incus-stable | sh
incus admin init --auto
```


## Usage

The common workflow is to run the `build.sh` script with the Windows
version you want to have an VM image for. If you'd like to use a
custom ISO or , read below.

Note that, unless the user changed the unattended install configuration,
all systems have an administrator-level account named `admin` with
password `changeme`.

```
# Build a disk image (disk.qcow2) and metadata archive (incus.tar.xz)
# in ./output/win2022/
sh incus-windows/build.sh 2022

# Import into incus using helper script
sh incus-windows/tools/import.sh ./output/win2022/

# Create and launch the virtual machine
incus init win2022 w22 -c security.secureboot=false
incus config device add w22 iso-agent disk source=agent:config
incus start w22
incus init win2008 w2k8 -c security.secureboot=false -c security.csm=true
incus config device add w2k8 iso-agent source=agent:config
incus start w2k8

# Optionally, create a profile for easier launches
incus profile create winvm
incus profile device add winvm iso-agent source=agent:config
incus launch win2022 w22 -p default -p winvm
```

## Customizations

### Adding files

One can add a directory to add to the boot image and have a script in
it be called automatically during configuration.

```
mkdir local/
echo "echo hi" >local/main.ps1
sh build.sh 2025 local/
```

On the image, the directory will be located at `X:\local\`, if `X` is
the drive.

### Custom ISO and `Autounattend.xml`

There are two (2) options that can be useful to further customize the
build process and image. **Note that support for this kind of installs
will not be provided by this project**.

- `-i` can be used to specify the local path to the Windows installer ISO
  to use. This could be used for alternate Windows builds.
- `-x` can be used to specify the local path to an `Autounattend.xml`
  allowing for installation tweaking.

Note that the version tag must still match an existing targets.

```
sh build.sh -i my.iso -x my.xml 10e
```

## Considerations

### Missing updates

Configurations are meant to support offline installs. This supports
ensuring that no updates are part of the images. In other words, we're
able to control when, if any, updates/patches will be installed.

### Storage space

Make sure the project's partition has enough storage space.

- The Windows ISOs and virtio drivers' ISO are automatically downloaded
  into the `./isos/` directory.
- The `./tmp/` directory is used to repack the virtio drivers' ISO with
  additional installation files.
- The `./output/` directory will contain the VM's disk image, metadata
  tarball and unattended install ISO.

### Windows Server 2008 R2 SP1

Windows Server 2008 R2 SP1 is EOL since 2020. However, it still used by
some organizations. For this reason, being able to deploy it in a lab
environment is desired. However, compared to other Windows versions,
automatic configuration is only minimally done/supported. If you'd
like to build a relatively similar image:

- let Windows install itself using the provided `Autounattend.xml`;
- on the desktop, open `powershell` and run `E:\OEM\install-ps3.ps1` (this can take a while);
- on reboot (automatic), open `powershell` and run `E:\OEM\ConfigureRemotingForAnsible.ps1`;
- run `E:\OEM\power.ps1`;
- run `E:\OEM\qemu-ga.ps1`;
- finally, run `E:\OEM\sysprep.bat E:\OEM\unattend.xml`.

### Serial console access

It is possible to access Windows's serial console interface by
installing the EMS/SAC service. An installation script is provided by
disabled. To install EMS/SAC simply uncomment the instruction in the
`oem/main.ps1` file. Note that installing EMS/SAC on Windows 10
requires network connectivity and that it appears to be broken on
Server 2012.

```
incus console w22
SAC> cmd
SAC> ch -si 1
Username: admin
Domain:
Password: changeme
C:\Windows\System32>
```


## Funny stuff

- Incus supports setting the UEFI's boot priority through a
  `device` entry with the `boot.priority` parameter. This means
  that we can auto-"boot" to Window's ISO and launch the installer
  instead of spamming the Escape key to enter the boot menu. It is
  also possible to add ISOs using the `raw.qemu` parameter with a
  `-drive` option. The implication of using the former is
  that Windows won't mount the drive as a `X:\`-type drive.

  Windows Server 2019 and 2022 will install without issues with the
  ISOs attached to the VM in a split setup. However, versions 10,
  2012 and 2016 will only install if both ISOs are attached using
  `raw.qemu`. Without that configuration, the Windows installer will
  simply error out with an `invalid <ProductKey>` message.

  In other words, with the `device` parameter for booting and the
  double `-drive` parameter in `raw.qemu`, Windows 2012, 2016 and 10
  will see two (2) drives, but Windows 2019 and 2022 will see three (3).
  `Autounattend.xml` files have to be adjusted for this configuration.
  haha no, not exactly! Windows 10 sees two (2) devices during
  installation and three (3) afterwards. :p

  This is being dealt with automatically by the configuration script;
  which detects the setup drive and passes it around.
- EMS/SAC can be installed on the Server 2012 image, but doesn't seem to
  work.


## Debugging

You may connect and interact to the VM during the imaging process by using
the following commands:

```
# identify the vm
#> use the following command or check your console
incus ls build

# connect to to the vm
incus console --type=vga $vmname
```

Here are some breaking points that you might want to look at:

- `Autounattend.xml` and scripts refer to drives by letters. As
  mentionned in the `Fun facts` section, these tend to change
  depending on the setup. Use Shift+F10 to open up a console.

You may want to use Microsoft's official imaging toolkit to craft
or debug your `Autounattend.xml` file. See the references below
for more information.


## References

- https://github.com/ruzickap/packer-templates
- https://learn.microsoft.com/en-us/troubleshoot/windows-server/windows-server-eos-faq/end-of-support-windows-server-2008-2008r2
- https://github.com/lxc/incus/commit/f14c88de78bf9f2bbe91dd661004ab772ccf179e
- https://bugs.launchpad.net/qemu/+bug/1593605
- https://www.itninja.com/blog/view/validating-unattend-xml-files-with-system-image-manager
- https://vacuumbreather.com/index.php/blog/item/62-the-case-of-just-a-moment
- https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install

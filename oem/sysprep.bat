if exist C:\script.bat del C:\script.bat

mkdir %WINDIR%\Setup\Scripts

rem Disable WinRM when until Windows is fully initialized / started
netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=block
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=block
echo netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=allow ^>^> %%WINDIR%%\Temp\SetupComplete.log >> %WINDIR%\Setup\Scripts\SetupComplete.cmd
echo netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=allow ^>^> %%WINDIR%%\Temp\SetupComplete.log >> %WINDIR%\Setup\Scripts\SetupComplete.cmd
rem /generalize resets the WSMAN service config, so AllowUnencrypted has to
rem be (re)enabled after deployment; SetupComplete.cmd runs as SYSTEM
rem before the logon screen appears.
echo winrm set winrm/config/service @{AllowUnencrypted="true"} >> %WINDIR%\Setup\Scripts\SetupComplete.cmd

rem Remove per-user Edge so it can't fail sysprep /generalize. OOBE
rem reprovisions it on first boot.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -Name Microsoft.MicrosoftEdge.Stable | Remove-AppxPackage -ErrorAction SilentlyContinue" 2>nul

%WINDIR%\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:%1

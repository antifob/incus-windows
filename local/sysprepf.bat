if exist C:\script.bat del C:\script.bat

mkdir %WINDIR%\Setup\Scripts

rem Disable WinRM when until Windows is not fully initialized / started
netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=block
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=block
echo netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=allow ^>^> %%WINDIR%%\Temp\SetupComplete.log >> %WINDIR%\Setup\Scripts\SetupComplete.cmd
echo netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=allow ^>^> %%WINDIR%%\Temp\SetupComplete.log >> %WINDIR%\Setup\Scripts\SetupComplete.cmd

%WINDIR%\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:F:\local\unattend.xml

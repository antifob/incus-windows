if not "%~2"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0winre-legacy.ps1" "%~dp0..\%~2" >>"%WINDIR%\Temp\incus-winre.log" 2>&1
    if errorlevel 1 exit /b 1
)

if exist C:\script.bat del C:\script.bat

mkdir %WINDIR%\Setup\Scripts

rem Disable WinRM when until Windows is fully initialized / started
netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=block
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=block
echo netsh advfirewall firewall set rule name="Allow WinRM HTTPS" new action=allow ^>^> %%WINDIR%%\Temp\SetupComplete.log >> %WINDIR%\Setup\Scripts\SetupComplete.cmd
echo netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new action=allow ^>^> %%WINDIR%%\Temp\SetupComplete.log >> %WINDIR%\Setup\Scripts\SetupComplete.cmd

rem Server 2022 is build 20348; ProductType 1 is a workstation.
powershell -NoProfile -Command "$os = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop; if ($os.BuildNumber -ne '20348' -or $os.ProductType -eq 1) { exit 2 }"
if "%errorlevel%"=="2" goto legacy_edge
if not "%errorlevel%"=="0" exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0seal-edge.ps1" >>"%WINDIR%\Temp\incus-edge-seal.log" 2>&1 || exit /b 1
goto generalize

:legacy_edge
rem Remove per-user Edge so it can't fail sysprep /generalize. OOBE
rem reprovisions it on first boot.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-AppxPackage -Name Microsoft.MicrosoftEdge.Stable | Remove-AppxPackage -ErrorAction SilentlyContinue" 2>nul

:generalize
%WINDIR%\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:%1

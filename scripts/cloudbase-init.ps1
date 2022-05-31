curl "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi" -o "c:\windows\temp\CloudbaseInitSetup_Stable_x64.msi"

start-process -wait -filepath 'c:\Windows\temp\CloudbaseInitSetup_Stable_x64.msi' -argumentlist '/qn /l*v c:\windows\temp\cloudbase-init.log'

# verify that cloudbase-init tools exists
if (-not(test-path -path "c:\Program Files\cloudbase Solutions\cloudbase-Init\LocalScripts")) {
    Write-output "cloudbase-init not installed exiting..."
    exit 1
}

cp $psscriptroot/cloudbase-init.conf "c:/program files/cloudbase solutions/cloudbase-init/conf/cloudbase-init.conf"

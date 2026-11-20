param([switch]$Restore)
$ErrorActionPreference = 'Stop'
$scripts = "$env:SystemRoot\Setup\Scripts"
$journal = "$scripts\incus-edge-update.xml"
$retryTask = 'Incus-RestoreEdgeUpdate'

function EdgeTasks {
    Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'MicrosoftEdgeUpdate*' -and $_.Settings.Enabled }
}
function EdgeServices {
    Get-CimInstance Win32_Service -Filter "Name='edgeupdate' OR Name='edgeupdatem'" |
        Where-Object StartMode -ne 'Disabled'
}
function Set-StartMode($name, $mode) {
    # ChangeStartMode leaves the separate DelayedAutoStart flag untouched.
    $s = Get-CimInstance Win32_Service -Filter "Name='$name'"
    $result = Invoke-CimMethod -InputObject $s -MethodName ChangeStartMode -Arguments @{StartMode=$mode}
    if ($result.ReturnValue) { throw "Cannot set $name to $mode ($($result.ReturnValue))" }
}
function Restore-EdgeUpdate($path) {
    $saved = Import-Clixml -LiteralPath $path
    $services = @(foreach ($s in $saved.Services) {
        try { Set-StartMode $s.Name $s.Mode } catch { Write-Warning "Service $($s.Name): $_"; $s }
    })
    $tasks = @(foreach ($t in $saved.Tasks) {
        try { Enable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null }
        catch { Write-Warning "Task $($t.TaskPath)$($t.TaskName): $_"; $t }
    })
    if ($services.Count -or $tasks.Count) {
        @{ Services=$services; Tasks=$tasks } | Export-Clixml -LiteralPath "$path.new"
        [IO.File]::Replace("$path.new", $path, [System.Management.Automation.Language.NullString]::Value)
        throw "Unrestored Edge Update settings in $path"
    }
    Remove-Item -LiteralPath $path
}
function Stop-EdgeScheduler($w) {
    $p = Get-Process -Id $w.ProcessId -ErrorAction SilentlyContinue
    if (!$p) { return }
    try {
        # Pin the handle, then recheck the identity and command line before using it.
        $null = $p.get_Handle()
        $live = Get-CimInstance Win32_Process -Filter "ProcessId=$($w.ProcessId) AND Name='MicrosoftEdgeUpdate.exe'"
        if ($live -and $live.CreationDate -eq $w.CreationDate -and $live.CommandLine -match '\s/c\s*$') { $p.Kill() }
    } catch {
        if (!$p.HasExited) { throw }
    } finally { $p.Dispose() }
}
if ($Restore) {
    if (Test-Path "$journal.sealed") { return }
    if (Test-Path $journal) { Restore-EdgeUpdate $journal }
    Unregister-ScheduledTask -TaskPath '\' -TaskName $retryTask -Confirm:$false -ErrorAction Stop
    return
}
if ((Test-Path $journal) -or (Test-Path "$journal.sealed")) { throw "Unrestored Edge Update settings in $scripts" }

$tasks = @(EdgeTasks | Select-Object TaskPath, TaskName)
$services = @(foreach ($s in EdgeServices) {
    $mode = if ($s.StartMode -eq 'Auto') { 'Automatic' } else { $s.StartMode }
    [pscustomobject]@{ Name=$s.Name; Mode=$mode }
})
Copy-Item -LiteralPath $PSCommandPath -Destination "$scripts\seal-edge.ps1" -Force
@{ Tasks=$tasks; Services=$services } | Export-Clixml -LiteralPath "$journal.sealed"
try {
    foreach ($t in $tasks) { Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null }
    foreach ($s in $services) { Set-StartMode $s.Name 'Disabled' }

    # /c is the resident scheduler. Stop only that launcher; let workers and installers exit.
    $deadline = [datetime]::UtcNow.AddMinutes(10)
    do {
        $busy = @(Get-CimInstance Win32_Process | Where-Object {
            $_.Name -like 'MicrosoftEdgeUpdate*.exe' -or $_.Name -like 'MicrosoftEdge_*.exe' -or
            ($_.Name -eq 'setup.exe' -and ($_.ExecutablePath -like '*\Microsoft\Edge\*' -or $_.CommandLine -match '\s--msedge\b'))
        })
        if (!$busy.Count) { break }
        foreach ($w in $busy) {
            if ($w.Name -eq 'MicrosoftEdgeUpdate.exe' -and $w.CommandLine -match '\s/c\s*$') { Stop-EdgeScheduler $w }
        }
        if ([datetime]::UtcNow -ge $deadline) { throw "Edge Update did not drain: $($busy.Name -join ', ')" }
        Start-Sleep -Seconds 1
    } while ($true)
    if ((EdgeTasks) -or (EdgeServices)) { throw 'Edge Update re-enabled a launch path while sealing' }

    $edge = 'Microsoft.MicrosoftEdge.Stable'
    $provisioned = @(Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $edge | ForEach-Object PackageName)
    function Get-EdgeBlockers {
        Get-AppxPackage -AllUsers -Name $edge | Where-Object {
            $_.PackageFullName -notin $provisioned -and $_.PackageUserInformation.InstallState -contains 'Installed'
        }
    }
    foreach ($pkg in Get-EdgeBlockers) {
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers
    }
    if (Get-EdgeBlockers) { throw 'Unprovisioned per-user Edge registration remains' }
    # Only SetupComplete releases the journal; the same SYSTEM task handles first run and retries.
    $action = New-ScheduledTaskAction -Execute "$PSHOME\powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `"& '$scripts\seal-edge.ps1' -Restore *> '$scripts\incus-edge-restore.log'`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 5)
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    Add-Content -Encoding Ascii -LiteralPath "$scripts\SetupComplete.cmd" -Value "move /y `"$journal.sealed`" `"$journal`" && schtasks /run /tn `"\$retryTask`""
    Register-ScheduledTask -TaskName $retryTask -User SYSTEM -Action $action -Trigger $trigger -Settings $settings -ErrorAction Stop | Out-Null
} catch {
    Restore-EdgeUpdate "$journal.sealed"
    throw
}

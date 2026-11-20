param([string]$Driver)
$ErrorActionPreference = 'Stop'
trap { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
$driver = (Get-Item -LiteralPath $Driver).FullName
$wim = "$env:SystemRoot\System32\Recovery\Winre.wim"

# Setup may already have moved WinRE to the recovery partition.
$info = reagentc.exe /info
if ($LASTEXITCODE) { throw "Cannot locate WinRE: $LASTEXITCODE" }
foreach ($line in $info) {
	if ($line -match '^\s*(?:Windows RE location|Recovery Environment):\s*(\S.*)$') {
		$wim = $matches[1].Trim() + '\Winre.wim'
		break
	}
}

$mount = "$env:TEMP\incus-winre"
New-Item -ItemType Directory -Path $mount | Out-Null
dism.exe /Mount-Wim "/WimFile:$wim" /Index:1 "/MountDir:$mount"
if ($LASTEXITCODE) {
	$rc = $LASTEXITCODE
	# Leave a nonempty mount for inspection; an empty directory blocks a retry.
	try { [IO.Directory]::Delete($mount) } catch { Write-Warning $_.Exception.Message }
	throw "Cannot mount ${wim}: $rc"
}
$action = '/discard'
try {
	dism.exe "/Image:$mount" /Add-Driver "/Driver:$driver"
	if ($LASTEXITCODE) { throw "Cannot add ${driver}: $LASTEXITCODE" }
	$action = '/commit'
} finally {
	dism.exe /Unmount-Wim "/MountDir:$mount" $action
	if ($LASTEXITCODE) { throw "Cannot unmount WinRE ($action): $LASTEXITCODE" }
	Remove-Item -LiteralPath $mount
}

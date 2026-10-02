<#
  RoxaZip - register the application for the Windows "Default apps" settings.

  This writes (needs administrator rights, the script elevates itself):

      HKLM\SOFTWARE\7-Zip-Zstandard\Capabilities
          ApplicationName        = RoxaZip
          ApplicationDescription = ...
          FileAssociations\.7z   = 7-Zip-Zstandard.7z
          ...
      HKLM\SOFTWARE\RegisteredApplications
          RoxaZip               = Software\7-Zip-Zstandard\Capabilities

  With that entry the options page ("System" tab -> double click a row) can open
  the app's own page in "Default apps" through
  IApplicationAssociationRegistrationUI::LaunchAdvancedAssociationUI(), where the
  user sets the default app per file type. Without the entry that call fails and
  the general settings page is opened instead.

      pwsh -File Package\register-app-capabilities.ps1
      pwsh -File Package\register-app-capabilities.ps1 -Uninstall
      pwsh -File Package\register-app-capabilities.ps1 -Status
#>
param(
  [string]$AppName = '7-Zip ZS',
  [string]$CapabilitiesPath = 'Software\7-Zip-Zstandard\Capabilities',
  [string]$ProgIdPrefix = '7-Zip-Zstandard',
  # only file types whose ProgID <ProgIdPrefix>.<ext> exists are registered
  [string[]]$Exts = @(
    '7z', 'zip', 'rar', 'xz', 'txz', 'lzma', 'lzma2', 'tar', 'cpio',
    'bz2', 'bzip2', 'tbz', 'tbz2', 'gz', 'gzip', 'tgz', 'tpz', 'z', 'taz',
    'lz', 'tlz', '001', 'cab', 'iso', 'wim', 'swm', 'esd', 'arj', 'lzh',
    'rpm', 'deb', 'zst', 'tzst', 'apfs', 'squashfs', 'vhd', 'vhdx', 'vdi', 'qcow2'
  ),
  [switch]$Uninstall,
  [switch]$Status
)

$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "  $m" }

$regCap = "HKLM\$CapabilitiesPath"
$regApp = 'HKLM\SOFTWARE\RegisteredApplications'

function Get-RegisteredName()
{
  $key = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\RegisteredApplications'
  if (-not (Test-Path -LiteralPath $key)) { return $null }
  $item = Get-Item -LiteralPath $key
  foreach ($n in $item.Property)
  {
    if ($item.GetValue($n) -eq $CapabilitiesPath) { return $n }
  }
  return $null
}

if ($Status)
{
  $name = Get-RegisteredName
  if ($name) { Info "registered as '$name' -> $CapabilitiesPath" } else { Info 'not registered' }
  exit 0
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin)
{
  Write-Host 'Restarting with administrator rights (UAC) ...'
  $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -AppName "{1}" -CapabilitiesPath "{2}" -ProgIdPrefix "{3}"' -f `
    $PSCommandPath, $AppName, $CapabilitiesPath, $ProgIdPrefix
  if ($Uninstall) { $argLine += ' -Uninstall' }
  if ($Status) { $argLine += ' -Status' }
  $p = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $argLine -Verb RunAs -Wait -PassThru
  exit $p.ExitCode
}

if ($Uninstall)
{
  Write-Host "`n== Removing the registration" -ForegroundColor Cyan
  foreach ($k in @($regCap, "HKLM\SOFTWARE\7-Zip-Zstandard")) { & reg.exe delete "$k" /f 2>$null | Out-Null }
  $name = Get-RegisteredName
  if ($name) { & reg.exe delete "$regApp" /v "$name" /f 2>$null | Out-Null }
  if (Get-RegisteredName) { Info 'WARN   the RegisteredApplications value is still there' }
  else { Info 'removed' }
  exit 0
}

Write-Host "`n== Registering the application" -ForegroundColor Cyan
& reg.exe add "$regCap" /v ApplicationName /t REG_SZ /d "RoxaZip" /f | Out-Null
& reg.exe add "$regCap" /v ApplicationDescription /t REG_SZ /d "RoxaZip archiver" /f | Out-Null

$count = 0
foreach ($ext in $Exts)
{
  $progId = "$ProgIdPrefix.$ext"
  if (-not (Test-Path -LiteralPath "Registry::HKEY_CLASSES_ROOT\$progId")) { continue }
  & reg.exe add "$regCap\FileAssociations" /v ".$ext" /t REG_SZ /d "$progId" /f | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Could not register .$ext" }
  # Repair values written by earlier versions, without touching other mappings.
  $assocKey = Get-Item -LiteralPath "Registry::HKEY_LOCAL_MACHINE\$CapabilitiesPath\FileAssociations"
  if ($assocKey.GetValue($ext) -eq $progId) {
    Remove-ItemProperty -LiteralPath $assocKey.PSPath -Name $ext
  }
  $count++
}
Info "file types registered: $count"

# the old name of a previous run is removed, so only one entry stays
$old = Get-RegisteredName
if ($old -and $old -ne $AppName) { & reg.exe delete "$regApp" /v "$old" /f 2>$null | Out-Null }
& reg.exe add "$regApp" /v "$AppName" /t REG_SZ /d "$CapabilitiesPath" /f | Out-Null

$name = Get-RegisteredName
if ($name) { Info "RegisteredApplications: '$name' -> $CapabilitiesPath" }
else { Info 'FAILED  the RegisteredApplications value was not written' }
Write-Host "`nDone." -ForegroundColor Green

<#
  RoxaZip - remove the duplicate entry in the classic context menu.

  Windows 11 shows the commands of a sparse package ("windows.fileExplorerContextMenus")
  in BOTH context menus: the modern one and the classic one ("Show more options").
  If the classic shell extension registration is still present, the classic menu
  lists "RoxaZip" twice.

  This script removes only the classic *context menu* registration:

      HKCR\{*,Folder,Directory,Drive}\shellex\ContextMenuHandlers\RoxaZip
      HKCR\{*,Folder,Directory,Drive}\shellex\ContextMenuHandlers\7-Zip-Zstandard

  The second (legacy) key name is what builds before the rename registered. An
  in-place upgrade keeps it, and because it points to the previous shell
  extension DLL, Explorer can show the entry twice; remove it with this script:

      pwsh -File Package\disable-legacy-shell-ext.ps1

  Only the context menu handler is removed:

    * the drag&drop registration is kept,
    * the packaged command (and therefore the modern menu) is kept,
    * the entries are exported to Package\Output\legacy-shellext-*.reg first.

  Usage (self-elevates, one UAC prompt):

      pwsh -File Package\disable-legacy-shell-ext.ps1            # remove + backup
      pwsh -File Package\disable-legacy-shell-ext.ps1 -Restore   # put them back

  Note: the "Options > System/Integration" page of RoxaZipFM.exe (or re-running the
  installer) re-creates the current key.
#>
param(
  [switch]$Restore,
  [string]$KeyName = 'RoxaZip',
  # key name used by builds before the rename; an upgrade leaves it behind
  [string]$LegacyKeyName = '7-Zip-Zstandard',
  [string]$BackupDir
)

$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "  $m" }

$roots = @('*', 'Folder', 'Directory', 'Drive')
$keyNames = @($KeyName, $LegacyKeyName) | Where-Object { $_ } | Select-Object -Unique

if (-not $BackupDir) { $BackupDir = Join-Path $PSScriptRoot 'Output' }

# ---------------------------------------------------------- self-elevation ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin)
{
  Write-Host 'Restarting with administrator rights (UAC) ...'
  $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -KeyName "{1}" -LegacyKeyName "{2}" -BackupDir "{3}"' -f `
    $PSCommandPath, $KeyName, $LegacyKeyName, $BackupDir
  if ($Restore) { $argLine += ' -Restore' }
  $p = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $argLine -Verb RunAs -Wait -PassThru
  exit $p.ExitCode
}

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

function Get-SafeName([string]$root) { return ($root -replace '[\\/:*?"<>|]', '_') }

if ($Restore)
{
  $files = Get-ChildItem $BackupDir -Filter 'legacy-shellext-*.reg' -ErrorAction SilentlyContinue
  if (-not $files) { Write-Host "no backup found in $BackupDir" -ForegroundColor Yellow; exit 1 }
  foreach ($f in $files)
  {
    & reg.exe import "$($f.FullName)" | Out-Null
    Info "restored: $($f.Name)"
  }
  Write-Host 'Done. The classic context menu entry is registered again.' -ForegroundColor Green
  exit 0
}

$removed = 0
foreach ($name in $keyNames)
{
  foreach ($root in $roots)
  {
    $key = "HKCR\$root\shellex\ContextMenuHandlers\$name"
    # -LiteralPath: the root "*" would otherwise be treated as a wildcard and the
    # whole HKEY_CLASSES_ROOT tree would be enumerated (looks like a hang).
    $regPath = "Registry::HKEY_CLASSES_ROOT\$root\shellex\ContextMenuHandlers\$name"
    if (-not (Test-Path -LiteralPath $regPath))
    {
      Info "not present : $key"
      continue
    }
    $backup = Join-Path $BackupDir ("legacy-shellext-{0}-{1}.reg" -f (Get-SafeName $name), (Get-SafeName $root))
    & reg.exe export "$key" "$backup" /y | Out-Null
    Info "backed up   : $key  ->  $(Split-Path $backup -Leaf)"
    & reg.exe delete "$key" /f | Out-Null
    if (Test-Path -LiteralPath $regPath)
    {
      Info "FAILED      : $key"
    }
    else
    {
      Info "removed     : $key"
      $removed++
    }
  }
}

Write-Host ''
if ($removed -gt 0)
{
  Write-Host "Removed $removed classic registration(s)." -ForegroundColor Green
  Write-Host 'The packaged command (modern menu) is untouched: verify with' -ForegroundColor Green
  Write-Host '    pwsh -File Package\verify-shell-package.ps1' -ForegroundColor Green
  Write-Host 'The classic menu should now list "RoxaZip" only once.' -ForegroundColor Green
}
else { Write-Host 'Nothing to do.' -ForegroundColor Yellow }

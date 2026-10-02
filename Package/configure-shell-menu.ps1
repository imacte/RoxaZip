# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
<#
  RoxaZip - choose in which File Explorer context menu(s) RoxaZip appears.

      pwsh -File Package\configure-shell-menu.ps1                  # show the current state
      pwsh -File Package\configure-shell-menu.ps1 -Mode Modern     # Windows 11 menu (+ classic for folders)
      pwsh -File Package\configure-shell-menu.ps1 -Mode Classic    # classic "Show more options" only
      pwsh -File Package\configure-shell-menu.ps1 -Mode Both       # both variants (classic menu then lists it twice)
      pwsh -File Package\configure-shell-menu.ps1 -Mode None       # neither

  How the two menus work (measured on Windows 11 26200):

    * The Windows 11 (compact) menu uses the commands of the sparse package
      (windows.fileExplorerContextMenus) for files and folders.
    * The classic menu ("Show more options") lists the commands of a sparse
      package for FILES, but not for DIRECTORIES. Directories there need the
      classic registration (HKCR\Folder, HKCR\Directory\shellex\ContextMenuHandlers).
    * Therefore "Modern" = sparse package + classic registration for
      Folder/Directory: files come from the package in both menus, folders come
      from the package in the Windows 11 menu and from the classic registration
      in the classic menu - exactly one entry everywhere, no duplicates.
    * "Classic" is the pre-package behaviour: classic registration for *,
      Folder and Directory, no package. The Windows 11 menu then has no RoxaZip,
      but the classic menu has the full cascaded submenus (including HASH).
    * "Both" registers both variants, so the classic menu lists RoxaZip twice
      for files (flat from the package, cascaded from the classic registration).

  Registry changes need administrator rights; the script elevates itself once.
  Reading the state (-Status, the default) needs no elevation.
#>
param(
  [ValidateSet('Modern', 'Classic', 'Both', 'None')]
  [string]$Mode,
  [string]$KeyName = 'RoxaZip',
  [string]$Clsid = '{23170F69-20BB-278A-1000-000100020000}',
  [string]$ShellExtName = 'RoxaZip Shell Extension',
  [string]$PackageName = 'RoxaZip.ShellExtension',
  [string]$BackupDir,
  [string]$LogFile,
  # the program directory - used for the COM registration of the shell extension
  [string]$InstallDir = 'D:\Program Files\RoxaZip',
  [switch]$Status
)

$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "  $m" }
function Head($m) { Write-Host "`n== $m" -ForegroundColor Cyan }

if (-not $BackupDir) { $BackupDir = Join-Path $PSScriptRoot 'Output' }
$LogDir = $BackupDir
if (-not $LogFile) { $LogFile = Join-Path $LogDir 'configure-shell-menu.log' }
$allRoots = @('*', 'Folder', 'Directory')

# ------------------------------------------------------------- state helpers --
function Test-LegacyKey([string]$root)
{
  # -LiteralPath is required: for the PowerShell registry provider "*" is a
  # wildcard, and without it the whole HKEY_CLASSES_ROOT tree is enumerated
  return (Test-Path -LiteralPath "Registry::HKEY_CLASSES_ROOT\$root\shellex\ContextMenuHandlers\$KeyName")
}

function Get-LegacyRoots()
{
  $found = @()
  foreach ($root in $allRoots)
  {
    if (Test-LegacyKey $root) { $found += $root }
  }
  return $found
}

function Get-Pkg()
{
  return (Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue)
}

function Show-Status()
{
  $pkg = Get-Pkg
  $legacy = Get-LegacyRoots
  $hasStar = $legacy -contains '*'
  Head 'Current state'
  if ($pkg) { Info "Windows 11 (compact) menu : RoxaZip is registered  [$($pkg.PackageFullName)]" }
  else { Info 'Windows 11 (compact) menu : not registered' }
  if ($legacy.Count) { Info ("Classic (Show more options) : classic registration for: {0}" -f ($legacy -join ', ')) }
  else { Info 'Classic (Show more options) : no classic registration' }
  Write-Host ''
  if ($pkg -and $hasStar) { Info '=> both menus, but the classic menu lists RoxaZip twice for files' }
  elseif ($pkg -and $legacy.Count) { Info '=> Windows 11 menu + classic menu, one entry each (files: package, folders: classic registration)' }
  elseif ($pkg) { Info '=> Windows 11 menu everywhere; classic menu: files only (folders need Folder/Directory)' }
  elseif ($legacy.Count) { Info '=> classic menu only, with the full cascaded submenus' }
  else { Info '=> RoxaZip does not appear in any context menu' }
}

# -------------------------------------------------------------------- status --
if (-not $Mode -or $Status) { Show-Status; exit 0 }

# ------------------------------------------------------------------ elevation --
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin)
{
  Write-Host 'Restarting with administrator rights (UAC) ...'
  if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
  Remove-Item $LogFile -Force -ErrorAction SilentlyContinue
  $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -KeyName "{1}" -Clsid "{2}" -BackupDir "{3}" -Mode {4} -LogFile "{5}" -InstallDir "{6}" -PackageName "{7}" -ShellExtName "{8}"' -f `
    $PSCommandPath, $KeyName, $Clsid, $BackupDir, $Mode, $LogFile, $InstallDir, $PackageName, $ShellExtName
  $p = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList $argLine -Verb RunAs -Wait -PassThru
  if (Test-Path $LogFile) { Get-Content $LogFile | ForEach-Object { Write-Host $_ } }
  exit $p.ExitCode
}

Start-Transcript -Path $LogFile -Force | Out-Null

# ------------------------------------------------------------------ actions ---
function Remove-LegacyRegistration()
{
  if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
  foreach ($root in (Get-LegacyRoots))
  {
    $key = "HKCR\$root\shellex\ContextMenuHandlers\$KeyName"
    $safe = $root -replace '[\\/:*?"<>|]', '_'
    $backup = Join-Path $BackupDir ("legacy-shellext-{0}.reg" -f $safe)
    & reg.exe export "$key" "$backup" /y | Out-Null
    & reg.exe delete "$key" /f | Out-Null
    if (Test-LegacyKey $root) { Info "FAILED  remove $key" } else { Info "removed $key   (backup: $(Split-Path $backup -Leaf))" }
  }

  # The COM registration of the shell extension. The program's own unregister
  # path ("Integrate RoxaZip to shell context menu" off, or ... ) removes it, and
  # an extension without it cannot be loaded (the classic menu then stays empty).
  # In the Modern mode the sparse package provides the CLSID, so removing the
  # classic one is correct here as well.
  $clsidKey = "HKCR\CLSID\$Clsid"
  & reg.exe export "$clsidKey" (Join-Path $BackupDir 'legacy-clsid.reg') /y 2>$null | Out-Null
  & reg.exe delete "$clsidKey" /f 2>$null | Out-Null
  if (Test-Path -LiteralPath "Registry::HKEY_CLASSES_ROOT\CLSID\$Clsid")
  { Info "WARN   could not remove HKCR\CLSID\$Clsid" }
  else { Info "removed HKCR\CLSID\$Clsid" }
}

function Add-LegacyRegistration([switch]$OnlyFolders)
{
  # the 7-Zip registration uses "*", "Folder" and "Directory" for the context
  # menu (see CPP/7zip/UI/Explorer/RegistryContextMenu.cpp: k_shellex_Statuses)
  $list = if ($OnlyFolders) { @('Folder', 'Directory') } else { $allRoots }

  foreach ($root in $list)
  {
    # reg.exe treats the key name literally (New-Item has no -LiteralPath and the
    # PowerShell registry provider would treat "*" as a wildcard), and /ve writes
    # the (Default) value - the CLSID that the shell loads.
    $key = "HKCR\$root\shellex\ContextMenuHandlers\$KeyName"
    $regPath = "Registry::HKEY_CLASSES_ROOT\$root\shellex\ContextMenuHandlers\$KeyName"
    $existed = Test-Path -LiteralPath $regPath
    & reg.exe add "$key" /ve /t REG_SZ /d $Clsid /f | Out-Null
    if (-not (Test-Path -LiteralPath $regPath))
    {
      Info "FAILED  add $key"
      continue
    }

    $item = Get-Item -LiteralPath $regPath
    if ($item.GetValue('') -eq $Clsid)
    {
      if ($existed) { Info "already correct: $root" } else { Info "added   HKCR\$root\shellex\ContextMenuHandlers\$KeyName" }
    }
    else { Info "FAILED  value of $key = '$($item.GetValue(''))'" }

    # remove a stray named value that an earlier version of this script created
    if (@($item.Property) -contains '(default)')
    {
      Remove-ItemProperty -LiteralPath $regPath -Name '(default)' -ErrorAction SilentlyContinue
      Info "cleaned stray '(default)' value on $root"
    }
  }

  $approved = 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved'
  if (Test-Path -LiteralPath $approved)
  {
    Set-ItemProperty -LiteralPath $approved -Name $Clsid -Value $ShellExtName -ErrorAction SilentlyContinue
    Info "approved entry set to '$ShellExtName'"
  }

  # The COM registration of the shell extension. The 7-Zip installer writes it as
  # well, but the program's own unregister path deletes it - and without it the
  # shell cannot load the DLL, so the classic menu stays empty even though the
  # shellex keys above exist.
  $dllPath = Join-Path $InstallDir 'RoxaZipShell.dll'
  if (-not (Test-Path $dllPath))
  {
    Info "WARN   $dllPath not found - the COM registration was not written"
    return
  }
  $clsidPredicate = "HKCR\CLSID\$Clsid"
  & reg.exe add "$clsidPredicate" /ve /t REG_SZ /d $ShellExtName /f | Out-Null
  & reg.exe add "$clsidPredicate\InprocServer32" /ve /t REG_SZ /d "$dllPath" /f | Out-Null
  & reg.exe add "$clsidPredicate\InprocServer32" /v ThreadingModel /t REG_SZ /d Apartment /f | Out-Null
  $val = (Get-Item -LiteralPath "Registry::HKEY_CLASSES_ROOT\CLSID\$Clsid\InprocServer32" -ErrorAction SilentlyContinue).GetValue('')
  if ($val -like '*RoxaZipShell.dll') { Info "COM registration: HKCR\CLSID\$Clsid -> $val" }
  else { Info "FAILED  COM registration (value: '$val')" }
}

function Install-Package([bool]$enable)
{
  $pkg = Get-Pkg
  if ($enable)
  {
    if ($pkg) { Info "package already installed: $($pkg.PackageFullName)"; return }
    Info 'installing the sparse package (build-shell-package.ps1) ...'
    & (Join-Path $PSScriptRoot 'build-shell-package.ps1') -InstallDir $InstallDir | ForEach-Object { Info $_ }
    $pkg = Get-Pkg
    if (-not $pkg) { throw 'package installation failed' }
    Info "installed: $($pkg.PackageFullName)"
  }
  else
  {
    if (-not $pkg) { Info 'package is not installed'; return }
    Remove-AppxPackage -Package $pkg.PackageFullName
    Info "removed package: $($pkg.PackageFullName)"
  }
}

function Restart-Explorer()
{
  Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
  Info 'File Explorer restarted (the shell needs a moment, or a sign-out, before the menus are complete again)'
}

# -------------------------------------------------------------------- main ----
Head "Switching to mode: $Mode"
switch ($Mode)
{
  'Modern'
  {
    Install-Package $true
    Remove-LegacyRegistration
    Add-LegacyRegistration -OnlyFolders
  }
  'Classic'
  {
    Install-Package $false
    Remove-LegacyRegistration
    Add-LegacyRegistration
  }
  'Both'
  {
    Install-Package $true
    Add-LegacyRegistration
    Write-Host '  NOTE: the classic menu lists RoxaZip twice for files (package + classic registration)' -ForegroundColor Yellow
  }
  'None'
  {
    Install-Package $false
    Remove-LegacyRegistration
  }
}

Restart-Explorer
Show-Status
Write-Host "`nDone. If a menu still looks stale, sign out and back in once." -ForegroundColor Green

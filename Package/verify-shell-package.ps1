# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
<#
  RoxaZip - verify the sparse package of the modern (Windows 11) context menu.

      pwsh -File Package\verify-shell-package.ps1

  It checks
    1. that the package is registered (Get-AppxPackage + its extensions),
    2. that the CLSID of the shell extension is registered as a *packaged* COM
       server (HKEY_CLASSES_ROOT\PackagedCom\ClassIndex) - this is what the
       Windows 11 context menu uses,
    3. with the native probe (Package\Output\probe-modern-menu.exe, build it with
       Package\build-probe.cmd) that the shell extension really answers like the
       shell expects it: the classic path inserts the "RoxaZip" submenu, and
       IExplorerCommand returns a root command with sub-commands (the cascaded
       submenu) - the titles are printed.

  Note: a managed (C#) test is NOT reliable for this DLL - COM interop reported
  bogus results (E_NOTIMPL / REGDB_E_CLASSNOTREG) where the native probe works.
#>
param(
  [string]$IdentityName = 'RoxaZip.ShellExtension',
  [string]$Clsid = '3878DDB7-37F6-4265-BB4F-835DC2A790ED',
  [string]$TargetFile = "$env:WINDIR\win.ini"
)

function Head($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
$ok = $true

Head 'Package registration'
$pkg = Get-AppxPackage -Name $IdentityName -ErrorAction SilentlyContinue
if (-not $pkg) { Write-Host '  NOT INSTALLED - run build-shell-package.ps1 first' -ForegroundColor Red; exit 1 }
Write-Host "  name       : $($pkg.Name)"
Write-Host "  full name  : $($pkg.PackageFullName)"
Write-Host "  install    : $($pkg.InstallLocation)"
if ($pkg.PSObject.Properties.Name -contains 'ExternalLocation') { Write-Host "  external   : $($pkg.ExternalLocation)" }

$manifest = Get-AppxPackageManifest -Package $pkg.PackageFullName
$app = $manifest.Package.Applications.Application
Write-Host "  executable : $($app.Executable)"
foreach ($e in @($app.Extensions.Extension))
{
  if ($e.ComServer)
  {
    Write-Host "  extension  : $($e.Category) -> $($e.ComServer.SurrogateServer.Class.Id) / $($e.ComServer.SurrogateServer.Class.Path) / $($e.ComServer.SurrogateServer.Class.ThreadingModel)"
  }
  else
  {
    $verbs = @($e.FileExplorerContextMenus.ItemType) | ForEach-Object { "$($_.Type)=$($_.Verb.Clsid)" }
    Write-Host "  extension  : $($e.Category) -> $($verbs -join ', ')"
  }
}

Head 'Packaged COM registration (used by the Windows 11 context menu)'
$root = 'Registry::HKEY_CLASSES_ROOT\PackagedCom\ClassIndex'
$hit = Get-ChildItem $root -ErrorAction SilentlyContinue |
  Where-Object { ($_.PSChildName -replace '[{}]', '') -eq $Clsid }
if ($hit)
{
  Write-Host "  HKCR\PackagedCom\ClassIndex\{$Clsid}"
  Get-ChildItem $hit.PSPath -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    -> $($_.PSChildName)" }
  Write-Host '  (the shell activates this CLSID with the package identity above)'
}
else { Write-Host "  NOT FOUND for $Clsid - the modern menu will not use this command" -ForegroundColor Red; $ok = $false }

Head 'Native probe (classic IContextMenu + IExplorerCommand)'
$probe = Join-Path $PSScriptRoot 'Output\probe-modern-menu.exe'
if (-not (Test-Path $probe))
{
  Write-Host '  probe not built - run Package\build-probe.cmd first' -ForegroundColor Yellow
  $ok = $false
}
else
{
  $outFile = Join-Path $env:TEMP "zs-probe-$PID.txt"
  # the probe writes UTF-8; wide strings are lost when printing to a GBK console
  & $probe $TargetFile *> $outFile
  $text = [System.IO.File]::ReadAllText($outFile, [System.Text.Encoding]::UTF8)
  Remove-Item $outFile -Force -ErrorAction SilentlyContinue
  $text -split "`r?`n" | Where-Object { $_ -match '\S' } | ForEach-Object { Write-Host "  $_" }

  if ($text -notmatch 'HASSUBCOMMANDS=yes') { Write-Host '  UNEXPECTED: the root command does not declare sub-commands' -ForegroundColor Yellow; $ok = $false }
  $m = [regex]::Match($text, 'sub-commands:\s*(\d+)')
  if (-not $m.Success -or [int]$m.Groups[1].Value -lt 2)
  {
    Write-Host '  UNEXPECTED: the cascaded submenu looks empty' -ForegroundColor Yellow
    $ok = $false
  }
}

Write-Host ''
if ($ok)
{
  Write-Host 'RESULT: OK - RoxaZip is registered for the Windows 11 context menu (cascaded submenu).' -ForegroundColor Green
  Write-Host '        Right-click a file/folder: "RoxaZip" should be in the modern menu.' -ForegroundColor Green
}
else { Write-Host 'RESULT: there are problems, see above.' -ForegroundColor Yellow }

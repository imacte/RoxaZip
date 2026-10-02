# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
<#
  RoxaZip - build, sign and register the sparse package that puts "RoxaZip"
  into the modern (Windows 11) File Explorer context menu.

  The package contains no binaries: it only gives the installed RoxaZip
  (RoxaZipShell.dll + RoxaZipFM.exe) a package identity and registers the IExplorerCommand
  implementation of RoxaZipShell.dll under "windows.fileExplorerContextMenus".

  Examples:
    # build + install for the current user (no administrator rights needed)
    pwsh -File Package\build-shell-package.ps1

    # another installation folder
    pwsh -File Package\build-shell-package.ps1 -InstallDir "C:\Program Files\RoxaZip"

    # recreate the self-signed development certificate, then build + install
    pwsh -File Package\build-shell-package.ps1 -MakeCert

    # unregister the package
    pwsh -File Package\build-shell-package.ps1 -Uninstall

  Release builds should use a real code signing certificate; pass it with
  -CertThumbprint (and keep Identity/@Publisher in AppxManifest.xml in sync
  with the certificate subject).
#>
param(
  [string]$InstallDir = 'D:\Program Files\RoxaZip',
  [string]$Subject = 'CN=7-Zip ZS Sparse Package',
  [string]$CertThumbprint,
  [string]$OutDir,
  [switch]$MakeCert,
  [switch]$Uninstall,
  [switch]$RestartExplorer,
  [switch]$KeepPackageFile
)

$ErrorActionPreference = 'Stop'
$pkgDir = $PSScriptRoot
$assetsDir = Join-Path $pkgDir 'Assets'
$identityName = 'RoxaZip.ShellExtension'

function Info($m) { Write-Host "  $m" }
function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host "  ERROR: $m" -ForegroundColor Red; exit 1 }

function Get-SdkTool([string]$name)
{
  $roots = @(
    'C:\Program Files (x86)\Windows Kits\10\bin',
    'C:\Program Files\Windows Kits\10\bin'
  )
  foreach ($r in $roots)
  {
    if (-not (Test-Path $r)) { continue }
    $hit = Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending |
      ForEach-Object { Join-Path $_.FullName "x64\$name" } |
      Where-Object { Test-Path $_ } |
      Select-Object -First 1
    if ($hit) { return $hit }
  }
  return $null
}

# ---------------------------------------------------------------- uninstall ---
if ($Uninstall)
{
  Step "Removing the sparse package"
  $pkg = Get-AppxPackage -Name $identityName -ErrorAction SilentlyContinue
  if ($pkg)
  {
    Remove-AppxPackage -Package $pkg.PackageFullName
    Info "removed: $($pkg.PackageFullName)"
  }
  else { Info "package is not installed" }
  Info "the classic (legacy) context menu is not touched by this script."
  exit 0
}

# ------------------------------------------------------------------- checks ---
Step "Checking the RoxaZip installation"
$dll = Join-Path $InstallDir 'RoxaZipShell.dll'
$exe = Join-Path $InstallDir 'RoxaZipFM.exe'
foreach ($f in @($dll, $exe))
{
  if (-not (Test-Path $f)) { Fail "not found: $f  (use -InstallDir <folder>)" }
}
Info "install dir : $InstallDir"
Info "RoxaZipShell.dll : $((Get-Item $dll).Length) bytes  $((Get-FileHash $dll -Algorithm SHA256).Hash.Substring(0,16))"
Info "RoxaZipFM.exe    : $((Get-Item $exe).Length) bytes"

$makeappx = Get-SdkTool 'makeappx.exe'
$signtool = Get-SdkTool 'signtool.exe'
if (-not $makeappx) { Fail 'makeappx.exe not found (install the Windows SDK)' }
if (-not $signtool) { Fail 'signtool.exe not found (install the Windows SDK)' }
Info "makeappx    : $makeappx"

# ------------------------------------------------------------------- assets ---
Step "Preparing the package assets"
foreach ($name in @('StoreLogo.png', 'Square44x44Logo.png', 'Square150x150Logo.png'))
{
  if (-not (Test-Path -LiteralPath (Join-Path $assetsDir $name)))
  {
    Fail "missing icon asset: $name. Restore Package/Assets or run npm ci and npm run build in design/icons."
  }
}
Get-ChildItem $assetsDir -Filter *.png | ForEach-Object { Info ("asset       : {0} ({1} bytes)" -f $_.Name, $_.Length) }

# --------------------------------------------------------------- certificate ---
Step "Code signing certificate"
$cert = $null
if ($CertThumbprint)
{
  $cert = Get-Item "Cert:\CurrentUser\My\$CertThumbprint" -ErrorAction SilentlyContinue
  if (-not $cert) { $cert = Get-Item "Cert:\LocalMachine\My\$CertThumbprint" -ErrorAction SilentlyContinue }
  if (-not $cert) { Fail "certificate not found: $CertThumbprint" }
  Info "using certificate : $($cert.Subject)"
}
else
{
  $cert = Get-ChildItem 'Cert:\CurrentUser\My' -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -eq $Subject -and $_.HasPrivateKey } |
    Sort-Object NotAfter -Descending | Select-Object -First 1

  if ($MakeCert -or -not $cert)
  {
    if ($cert) { Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force }
    Info "creating a self-signed development certificate ..."
    $cert = New-SelfSignedCertificate `
      -Type Custom `
      -Subject $Subject `
      -KeyUsage DigitalSignature `
      -FriendlyName 'RoxaZip sparse package (development)' `
      -CertStoreLocation 'Cert:\CurrentUser\My' `
      -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}') `
      -NotAfter (Get-Date).AddYears(5)
  }
  Info "certificate       : $($cert.Subject)  [$($cert.Thumbprint)]"

  # the package can only be installed when the signing certificate is trusted
  $trusted = Get-ChildItem 'Cert:\CurrentUser\TrustedPeople' -ErrorAction SilentlyContinue |
    Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
  if (-not $trusted)
  {
    $cer = Join-Path $env:TEMP "7zipzs-sparse-$($cert.Thumbprint).cer"
    Export-Certificate -Cert $cert -FilePath $cer -Type CERT | Out-Null
    Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
    Remove-Item $cer -Force -ErrorAction SilentlyContinue
    Info "certificate added to Cert:\CurrentUser\TrustedPeople"
  }
  else { Info "certificate is already trusted for the current user" }
}

# ------------------------------------------------------- machine trust -------
# Sideloading checks the root of the signature chain, so the certificate must be
# trusted machine-wide (Cert:\LocalMachine\TrustedPeople). This is the only step
# of this script that needs administrator rights (a UAC prompt).
$machineTrusted = Get-ChildItem 'Cert:\LocalMachine\TrustedPeople' -ErrorAction SilentlyContinue |
  Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
if (-not $machineTrusted)
{
  Step "Trusting the certificate for the machine (needs administrator rights once)"
  $cer = Join-Path $env:TEMP "7zipzs-sparse-$($cert.Thumbprint).cer"
  Export-Certificate -Cert $cert -FilePath $cer -Type CERT | Out-Null
  $p = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\certutil.exe') `
    -ArgumentList @('-addstore', '-f', 'TrustedPeople', $cer) `
    -Verb RunAs -Wait -PassThru
  Remove-Item $cer -Force -ErrorAction SilentlyContinue
  if ($p.ExitCode -ne 0)
  {
    Fail "could not add the certificate to Cert:\LocalMachine\TrustedPeople (certutil exit code $($p.ExitCode))"
  }
  Info "certificate added to Cert:\LocalMachine\TrustedPeople"
}
else { Info "certificate is already trusted for the machine" }

# ---------------------------------------------------------------- makeappx ---
Step "Packing the sparse package"
$stage = Join-Path $env:TEMP "7zipzs-sparse-stage-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item (Join-Path $pkgDir 'AppxManifest.xml') $stage
Copy-Item $assetsDir (Join-Path $stage 'Assets') -Recurse

if (-not $OutDir) { $OutDir = Join-Path $pkgDir 'Output' }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$msix = Join-Path $OutDir "$identityName`_1.0.0.0_x64.msix"
Remove-Item $msix -Force -ErrorAction SilentlyContinue

& $makeappx pack /o /nv /nfv /d $stage /p $msix | ForEach-Object { Info $_ }
if ($LASTEXITCODE -ne 0) { Fail "makeappx failed ($LASTEXITCODE)" }
Info "package     : $msix ($((Get-Item $msix).Length) bytes)"

# ------------------------------------------------------------------- sign ----
Step "Signing the package"
& $signtool sign /fd SHA256 /sha1 $cert.Thumbprint $msix | ForEach-Object { Info $_ }
if ($LASTEXITCODE -ne 0) { Fail "signtool failed ($LASTEXITCODE)" }
& $signtool verify /pa $msix | ForEach-Object { Info $_ }
Info "signature verified"

# --------------------------------------------------------------- register ----
Step "Registering the sparse package (per user, no administrator rights needed)"
# Add-AppxPackage reports "already installed" (0x80073CFB) for the same version.
# Only that error is resolved by unregister + retry; any other failure is reported
# instead of silently removing a registration that already worked.
try
{
  Add-AppxPackage -Path $msix -ExternalLocation $InstallDir -ErrorAction Stop
}
catch
{
  if ($_.Exception.HResult -ne 0x80073CFB) { Fail "registration failed: $($_.Exception.Message)" }
  $existing = Get-AppxPackage -Name $identityName -ErrorAction SilentlyContinue
  if ($existing) { Remove-AppxPackage -Package $existing.PackageFullName }
  Info "removed the previous registration"
  Add-AppxPackage -Path $msix -ExternalLocation $InstallDir -ErrorAction Stop
}
$pkg = Get-AppxPackage -Name $identityName
if (-not $pkg) { Fail 'registration failed' }
Info "registered  : $($pkg.PackageFullName)"
Info "external dir: $InstallDir"

if ($RestartExplorer)
{
  Step "Restarting File Explorer"
  Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
  Info "File Explorer restarted"
}

if (-not $KeepPackageFile) { }
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nDone. Right-click any file or folder: 'RoxaZip' should now appear in the" -ForegroundColor Green
Write-Host "Windows 11 context menu (with a cascaded submenu), not only under 'Show more options'." -ForegroundColor Green
Write-Host "If it does not appear, sign out and back in (or run with -RestartExplorer)." -ForegroundColor Green

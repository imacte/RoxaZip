# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
<#
  RoxaZip - build the full MSIX package for the Microsoft Store.

  The package contains the whole program (unlike ..\Package, which only builds
  the sparse package for an existing classic installation). It is what gives
  RoxaZip a package identity, and with it:

    - the Windows 11 context menu entry (windows.fileExplorerContextMenus),
    - the 7-Zip command names (7z.exe, 7zFM.exe, 7zG.exe) as execution aliases
      that Windows puts into %LOCALAPPDATA%\Microsoft\WindowsApps - no files in
      the installation folder,
    - the file associations from the manifest.

  The Store signs the uploaded package itself, so the result is unsigned by
  default. -Sign is only for a local test with a self-signed certificate.

  Examples:
    # build for the local test (unsigned)
    pwsh -File RoxaZipPackage\build-store-package.ps1

    # with the values from Partner Center
    pwsh -File RoxaZipPackage\build-store-package.ps1 `
      -IdentityName '12345RoxaZip.RoxaZip' `
      -Publisher 'CN=1A2B3C4D-....' `
      -PublisherDisplayName 'RoxaZip'

    # local test: sign with a self-signed certificate and install it
    pwsh -File RoxaZipPackage\build-store-package.ps1 -Sign -MakeCert -Install

    # remove the test package again
    Get-AppxPackage -Name 'RoxaZip.StorePlaceholder' | Remove-AppxPackage
#>
param(
  # built binaries; defaults to the newest build\bin-<arch>[-ndm] directory
  [string]$SourceDir,
  # the classic installation to take Lang\, RoxaZip.chm and the text files from
  [string]$InstallDir = 'D:\Program Files\RoxaZip',
  [ValidateSet('x64', 'arm64', 'x86')]
  [string]$Arch = 'x64',
  [string]$Version = '26.3.0.0',
  # Partner Center -> Product identity; empty keeps the placeholder in the manifest
  [string]$IdentityName,
  [string]$Publisher,
  [string]$PublisherDisplayName,
  [string]$OutDir,
  # local test only: the Store signs the uploaded package
  [switch]$Sign,
  [string]$CertThumbprint,
  [switch]$MakeCert,
  [string]$Subject = 'CN=RoxaZip Store Development',
  [switch]$Install,
  [switch]$KeepStage
)

$ErrorActionPreference = 'Stop'
$pkgDir = $PSScriptRoot
$repoRoot = Split-Path $pkgDir -Parent

function Info($m) { Write-Host "  $m" }
function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host "  ERROR: $m" -ForegroundColor Red; exit 1 }

function Get-SdkTool([string]$name)
{
  foreach ($r in @('C:\Program Files (x86)\Windows Kits\10\bin', 'C:\Program Files\Windows Kits\10\bin'))
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

# The manifest needs four version parts ("26.03" and "26.3.0.0" both work).
$vParts = @($Version.Split('.') | ForEach-Object { [int]$_ })
while ($vParts.Count -lt 4) { $vParts += 0 }
$Version = ($vParts[0..3] -join '.')

# --------------------------------------------------------------- source dir ---
Step "Locating the binaries"
if (-not $SourceDir)
{
  $candidates = @(
    (Join-Path $repoRoot "build\bin-$Arch-ndm"),
    (Join-Path $repoRoot "build\bin-$Arch")
  )
  $SourceDir = $candidates | Where-Object { Test-Path (Join-Path $_ 'RoxaZipFM.exe') } | Select-Object -First 1
}
if (-not $SourceDir -or -not (Test-Path (Join-Path $SourceDir 'RoxaZipFM.exe')))
{
  Fail "no $Arch build found (looked in build\bin-$Arch[-ndm]); build it first, or pass -SourceDir"
}
Info "source dir : $SourceDir"

# The manifest lists the executables, everything else is optional.
$binaries = @(
  'RoxaZip.dll', 'RoxaZip.exe', 'RoxaZipFM.exe', 'RoxaZipG.exe',
  'RoxaZipA.exe', 'RoxaZipA.dll', 'RoxaZipXA.dll', 'RoxaZipShell.dll',
  'RoxaZip.sfx', 'RoxaZipCon.sfx',
  # codec plugins; the main RoxaZip.dll already contains them, these are for
  # other hosts, but shipping them keeps the package equal to the release
  'brotli.dll', 'flzma2.dll', 'lizard.dll', 'lz4.dll', 'lz5.dll', 'zstd.dll'
)
if ($Arch -eq 'x64') { $binaries += 'RoxaZipShell32.dll' }

# files of the classic payload (upstream skeleton) that belong into the package
$extras = @('RoxaZip.chm', 'descript.ion', 'History.txt', 'License.txt', 'readme.txt')

# ----------------------------------------------------------------- staging ---
Step "Staging the package"
$stage = Join-Path $env:TEMP "roxazip-store-stage-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $stage | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage 'Assets') | Out-Null

$copied = 0
foreach ($name in $binaries)
{
  $src = Join-Path $SourceDir $name
  if (-not (Test-Path $src))
  {
    # the manifest needs these four; the rest is optional
    if ($name -in @('RoxaZip.dll', 'RoxaZip.exe', 'RoxaZipFM.exe', 'RoxaZipG.exe', 'RoxaZipShell.dll'))
    {
      Fail "missing required binary: $src"
    }
    Info "skip       : $name (not in the build)"
    continue
  }
  Copy-Item $src (Join-Path $stage $name) -Force
  $copied++
}
Info "binaries   : $copied"

if (Test-Path (Join-Path $SourceDir 'Lang'))
{
  Copy-Item (Join-Path $SourceDir 'Lang') (Join-Path $stage 'Lang') -Recurse -Force
  Info "Lang       : $((Get-ChildItem (Join-Path $stage 'Lang') -File | Measure-Object).Count) files from the source directory"
}
elseif (Test-Path $InstallDir)
{
  $lang = Join-Path $InstallDir 'Lang'
  if (Test-Path $lang)
  {
    Copy-Item $lang (Join-Path $stage 'Lang') -Recurse -Force
    Info "Lang       : $((Get-ChildItem (Join-Path $stage 'Lang') -File | Measure-Object).Count) files"
  }
}
# the extra files come from the staged payload first (CI), then from an installed copy
foreach ($name in $extras)
{
  $src = Join-Path $SourceDir $name
  if (-not (Test-Path $src)) { $src = Join-Path $InstallDir $name }
  if (Test-Path $src) { Copy-Item $src (Join-Path $stage $name) -Force }
}
if (-not (Test-Path (Join-Path $stage 'Lang')) -and -not (Test-Path (Join-Path $stage 'RoxaZip.chm')))
{
  Info "note       : no Lang/help text files found - pass -SourceDir of a staged payload or -InstallDir"
}

$assets = Join-Path (Split-Path $pkgDir -Parent) 'Package\Assets'
if (-not (Test-Path (Join-Path $assets 'StoreLogo.png')))
{
  # a copied folder (a CI artifact, for example) carries its own Assets
  $assets = Join-Path $pkgDir 'Assets'
}
if (-not (Test-Path (Join-Path $assets 'StoreLogo.png'))) { Fail "no package assets in $assets" }
Get-ChildItem $assets -Filter *.png | ForEach-Object { Copy-Item $_.FullName (Join-Path $stage 'Assets') -Force }
Info "assets     : $((Get-ChildItem (Join-Path $stage 'Assets') -File | Measure-Object).Count) png"

# ---------------------------------------------------------------- manifest ----
Step "Preparing the manifest"
$manifest = Join-Path $stage 'AppxManifest.xml'
Copy-Item (Join-Path $pkgDir 'Package.appxmanifest') $manifest -Force
$xml = [xml](Get-Content $manifest -Raw)
$xml.Package.Identity.Version = $Version
# Without this the package is architecture "neutral" and the x64 and arm64
# packages would share one full name (the Store rejects that, and a neutral
# package would be offered on every device although the binaries are not).
[void]$xml.Package.Identity.SetAttribute('ProcessorArchitecture', $Arch)
if ($IdentityName) { $xml.Package.Identity.Name = $IdentityName }
if ($Publisher) { $xml.Package.Identity.Publisher = $Publisher }
if ($PublisherDisplayName) { $xml.Package.Properties.PublisherDisplayName = $PublisherDisplayName }
$xml.Save($manifest)
Info "identity   : $($xml.Package.Identity.Name)"
Info "publisher  : $($xml.Package.Identity.Publisher)"
Info "version    : $($xml.Package.Identity.Version)"
if ($xml.Package.Identity.Publisher -like '*PLACEHOLDER*' -and -not $Sign)
{
  Info "note       : placeholder publisher - pass -Publisher (Partner Center) before uploading"
}

# ------------------------------------------------------------------- pack -----
Step "Packing"
$makeappx = Get-SdkTool 'makeappx.exe'
if (-not $makeappx) { Fail 'makeappx.exe not found (install the Windows SDK)' }
if (-not $OutDir) { $OutDir = Join-Path $pkgDir 'Output' }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$msix = Join-Path $OutDir "RoxaZip_${Version}_$Arch.msix"
Remove-Item $msix -Force -ErrorAction SilentlyContinue
& $makeappx pack /o /d $stage /p $msix
if ($LASTEXITCODE -ne 0) { Fail "makeappx failed ($LASTEXITCODE)" }
Info "package    : $msix ($([math]::Round((Get-Item $msix).Length / 1MB, 1)) MB)"

# ------------------------------------------------------------------- sign -----
$cert = $null
if ($Sign)
{
  Step "Signing for the local test"
  $signtool = Get-SdkTool 'signtool.exe'
  if (-not $signtool) { Fail 'signtool.exe not found (install the Windows SDK)' }
  if ($CertThumbprint)
  {
    $cert = Get-Item "Cert:\CurrentUser\My\$CertThumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) { Fail "certificate not found: $CertThumbprint" }
  }
  else
  {
    $cert = Get-ChildItem 'Cert:\CurrentUser\My' -ErrorAction SilentlyContinue |
      Where-Object { $_.Subject -eq $Subject -and $_.HasPrivateKey } |
      Sort-Object NotAfter -Descending | Select-Object -First 1
    if ($MakeCert -or -not $cert)
    {
      if ($cert) { Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force }
      Info "creating a self-signed test certificate ..."
      $cert = New-SelfSignedCertificate -Type Custom -Subject $Subject `
        -KeyUsage DigitalSignature -FriendlyName 'RoxaZip Store package (test)' `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}') `
        -NotAfter (Get-Date).AddYears(5)
      $cer = Join-Path $env:TEMP "roxazip-store-$($cert.Thumbprint).cer"
      Export-Certificate -Cert $cert -FilePath $cer -Type CERT | Out-Null
      Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
      Remove-Item $cer -Force -ErrorAction SilentlyContinue
      Info "test certificate added to Cert:\CurrentUser\TrustedPeople"
    }
  }
  # the manifest publisher has to be the certificate subject for a test install
  if ($xml.Package.Identity.Publisher -ne $cert.Subject)
  {
    Info "note       : signing with '$($cert.Subject)' while the manifest says"
    Info "             '$($xml.Package.Identity.Publisher)' - editing the manifest to match"
    $xml.Package.Identity.Publisher = $cert.Subject
    $xml.Save($manifest)
    Remove-Item $msix -Force
    & $makeappx pack /o /d $stage /p $msix
    if ($LASTEXITCODE -ne 0) { Fail "makeappx failed ($LASTEXITCODE)" }
  }
  & $signtool sign /fd SHA256 /sha1 $cert.Thumbprint $msix | ForEach-Object { Info $_ }
  if ($LASTEXITCODE -ne 0) { Fail "signtool failed ($LASTEXITCODE)" }
  & $signtool verify /pa $msix | ForEach-Object { Info $_ }
  Info "signed     : $($cert.Subject)"
}

# ---------------------------------------------------------------- install -----
if ($Install)
{
  Step "Registering the test package"
  if (-not $Sign) { Fail '-Install needs -Sign (an unsigned package cannot be installed)' }
  # Sideloading checks the root of the signature chain, so the test certificate
  # has to be trusted machine-wide - the only step that needs administrator
  # rights (one UAC prompt). Cert:\CurrentUser\TrustedPeople is not enough.
  $machineTrusted = Get-ChildItem 'Cert:\LocalMachine\TrustedPeople' -ErrorAction SilentlyContinue |
    Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
  if (-not $machineTrusted)
  {
    Info "trusting the test certificate for the machine (UAC) ..."
    $cer = Join-Path $env:TEMP "roxazip-store-$($cert.Thumbprint).cer"
    Export-Certificate -Cert $cert -FilePath $cer -Type CERT | Out-Null
    $p = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\certutil.exe') `
      -ArgumentList @('-addstore', '-f', 'TrustedPeople', $cer) `
      -Verb RunAs -Wait -PassThru
    Remove-Item $cer -Force -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0)
    {
      Fail "could not add the test certificate to Cert:\LocalMachine\TrustedPeople (certutil exit code $($p.ExitCode))"
    }
    Info "certificate trusted for the machine"
  }
  else { Info "test certificate is already trusted for the machine" }

  # Add-AppxPackage refuses to replace a registration of the same version, and the
  # HRESULT it reports differs between Windows versions, so the previous *test*
  # registration is removed first. Only packages with the "Developer" signature
  # kind are touched: a Store installation of RoxaZip (SignatureKind "Store") is
  # never removed by this script.
  $old = @(Get-AppxPackage -Name $xml.Package.Identity.Name -ErrorAction SilentlyContinue |
      Where-Object { $_.SignatureKind -eq 'Developer' })
  if ($old.Count)
  {
    foreach ($o in $old) { Remove-AppxPackage -Package $o.PackageFullName }
    Info "removed the previous test registration ($($old.Count))"
  }
  try { Add-AppxPackage -Path $msix -ErrorAction Stop }
  catch { Fail "registration failed: $($_.Exception.Message)" }

  $pkg = Get-AppxPackage -Name $xml.Package.Identity.Name -ErrorAction SilentlyContinue |
    Where-Object { $_.SignatureKind -eq 'Developer' } | Sort-Object Version -Descending | Select-Object -First 1
  if (-not $pkg) { Fail 'registration failed' }
  Info "registered : $($pkg.PackageFullName)"
  Info "family     : $($pkg.PackageFamilyName)"
  Info "install    : $($pkg.InstallLocation)"
  Write-Host "`nCheck now: aliases in $env:LOCALAPPDATA\Microsoft\WindowsApps (7z.exe, 7zFM.exe, 7zG.exe,"
  Write-Host "RoxaZip*.exe) and the Windows 11 context menu entry. Sign out and back in if the menu"
  Write-Host "does not appear. Remove the test package with:"
  Write-Host "    Get-AppxPackage -Name '$($xml.Package.Identity.Name)' | Where-Object SignatureKind -eq Developer | Remove-AppxPackage"
}

if (-not $KeepStage) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue }
Info "done"

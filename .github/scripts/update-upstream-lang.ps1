<#
  RoxaZip - take the language files of a new upstream 7-Zip package into a folder.

  The payload language files (Lang\*.txt) are not in the upstream source tree and
  not in this repository either: they live in https://github.com/imacte/7zip, and
  the release builds fetch them from there
  (.github/scripts/fetch-upstream-lang.ps1). After a new upstream 7-Zip version is
  adopted, run this script to extract its language files and commit them in that
  repository:

    pwsh -File .github\scripts\update-upstream-lang.ps1 `
        -Installer 7z2604.exe -RoxaZip build\bin-x64-ndm\RoxaZip.exe -OutDir <clone>\Lang
    # then, in the clone:  git add Lang ; git commit ; git push

  The strings this fork adds are not written here; they stay in this repository
  (.github/scripts/lang-additions\) and are merged when the payload is packaged.

  Usage:
    pwsh -File .github\scripts\update-upstream-lang.ps1 -PayloadDir <dir with Lang\> -OutDir <dir>
    pwsh -File .github\scripts\update-upstream-lang.ps1 -Installer <7zXXXX.exe> -RoxaZip <RoxaZip.exe> -OutDir <dir>
    pwsh -File .github\scripts\update-upstream-lang.ps1 -InstallDir "D:\Program Files\RoxaZip" -OutDir <dir>
#>
param(
  [Parameter(Mandatory = $true)][string]$OutDir,
  [string]$PayloadDir,
  [string]$Installer,
  [string]$RoxaZip,
  [string]$InstallDir = 'D:\Program Files\RoxaZip'
)

$ErrorActionPreference = 'Stop'

function Info($m) { Write-Host "  $m" }

$temp = $null
$sourceDir = $null
if ($PayloadDir)
{
  $sourceDir = Join-Path $PayloadDir 'Lang'
}
elseif ($Installer)
{
  if (-not $RoxaZip) { throw '-Installer needs -RoxaZip: the console binary that unpacks it (build\bin-<arch>\RoxaZip.exe)' }
  if (-not (Test-Path -LiteralPath $RoxaZip)) { throw "no such console binary: $RoxaZip" }
  $temp = Join-Path $env:TEMP ("roxazip-lang-src-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $temp | Out-Null
  Info "unpacking $Installer with $RoxaZip"
  & $RoxaZip x $Installer "-o$temp" 'Lang\*' -y | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "unpacking failed ($LASTEXITCODE)" }
  $sourceDir = Join-Path $temp 'Lang'
}
else
{
  $sourceDir = Join-Path $InstallDir 'Lang'
}

if (-not (Test-Path -LiteralPath $sourceDir)) { throw "no language folder at $sourceDir - pass -PayloadDir, -Installer or -InstallDir" }
$files = @(Get-ChildItem -LiteralPath $sourceDir -File)
if ($files.Count -eq 0) { throw "no language files in $sourceDir" }

if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutDir | Out-Null
foreach ($f in $files)
{
  # a byte copy: Copy-Item would carry the attributes of a WindowsApps source
  [IO.File]::WriteAllBytes((Join-Path $OutDir $f.Name), [IO.File]::ReadAllBytes($f.FullName))
}

if ($temp) { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

Info "source  : $sourceDir ($($files.Count) files)"
Info "written : $OutDir ($((Get-ChildItem -LiteralPath $OutDir -File).Count) files)"
Info "next    : git add Lang && git commit && git push   (in the 7-Zip repository clone)"

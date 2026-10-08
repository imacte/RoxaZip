<#
  RoxaZip - take the payload language files from the 7-Zip repository.

  The language files are not part of the upstream 7-Zip source tree; they ship
  inside the official installer package. They are kept in
  https://github.com/imacte/7zip (Lang\, the unmodified upstream files, refreshed
  with .github/scripts/update-upstream-lang.ps1 after an upstream bump) and the
  release builds take them from that fixed, reviewable revision.

  The strings this fork adds are not in that folder; they are merged in afterwards
  by .github/scripts/apply-lang-additions.ps1.

  Only the Lang folder is downloaded (partial clone plus sparse checkout). A
  failure here does not have to break a release build: the caller keeps the
  language files of the upstream installer it already unpacked.

  Usage:
    pwsh -NoProfile -File .github/scripts/fetch-upstream-lang.ps1 -OutDir <dir>
#>
param(
  [Parameter(Mandatory = $true)][string]$OutDir,
  [string]$Repo = 'imacte/7zip',
  [string]$Ref = 'main'
)

$ErrorActionPreference = 'Stop'

$signature = ';!@Lang2@!UTF-8!'
$temp = Join-Path $env:TEMP ('roxazip-lang-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

try
{
  # partial clone + sparse checkout: only Lang\ is transferred
  & git clone --quiet --depth 1 --filter=blob:none --sparse --branch $Ref "https://github.com/$Repo.git" $temp
  if ($LASTEXITCODE -ne 0) { throw "git clone of $Repo@$Ref failed ($LASTEXITCODE)" }
  & git -C $temp sparse-checkout set Lang
  if ($LASTEXITCODE -ne 0) { throw "sparse-checkout of Lang failed ($LASTEXITCODE)" }

  $src = Join-Path $temp 'Lang'
  if (-not (Test-Path $src)) { throw "$Repo@$Ref has no Lang folder" }
  $files = @(Get-ChildItem -LiteralPath $src -File)
  if ($files.Count -eq 0) { throw "$Repo@$Ref has an empty Lang folder" }

  # a wrong branch or path would silently ship garbage, so check the format
  foreach ($f in $files)
  {
    if ($f.Extension -eq '.ttt') { continue }
    $first = Get-Content -LiteralPath $f.FullName -TotalCount 1 -Encoding UTF8
    if ($first -ne $signature) { throw "$($f.Name) is not a 7-Zip language file (first line: '$first')" }
  }

  if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
  New-Item -ItemType Directory -Path $OutDir | Out-Null
  foreach ($f in $files) { Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $OutDir $f.Name) -Force }

  Write-Output "$Repo@$Ref -> $OutDir ($($files.Count) files)"
}
finally
{
  Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}

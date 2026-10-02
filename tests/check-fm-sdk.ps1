# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
# Run from a Visual Studio developer prompt; no build products are generated.
$ErrorActionPreference = 'Stop'
$rules = (Resolve-Path "$PSScriptRoot/../CPP/7zip/UI/FileManager/FMBuild.mak").Path
$dir = Join-Path $env:TEMP ('7zip-sdk-test-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $dir)
$sdkDir = $env:WindowsSdkDir
$sdkVersion = $env:WindowsSDKVersion
$override = $env:CPPWINRT_INCLUDE
$include = Join-Path $sdkDir ('Include/' + $sdkVersion + 'cppwinrt')
if (-not (Test-Path "$include/winrt/base.h")) { throw 'Run in a Windows SDK developer environment' }
$cache = Join-Path $dir 'cppwinrt_path.mak'
function Probe([bool]$success) {
  $output = & cmd /d /c 'nmake /nologo /f probe.mak probe 2>&1'
  if (($LASTEXITCODE -eq 0) -ne $success) { throw "Unexpected nmake result: $output" }
  if (-not $success -and ($output -join ' ') -notmatch 'CPPWINRT_INCLUDE') { throw "Missing SDK diagnostic: $output" }
}
try {
  Push-Location $dir
  [IO.File]::WriteAllText((Join-Path $dir 'probe.mak'), "probe:`n`t@echo SDK probe OK`n!INCLUDE `"$rules`"`n")
  $env:CPPWINRT_INCLUDE = $null
  # A configured SDK takes precedence over a stale cache and never overwrites it.
  [IO.File]::WriteAllText($cache, 'CPPWINRT_INCLUDE=%WindowsSdkDir%Include\%WindowsSDKVersion%cppwinrt')
  $original = [IO.File]::ReadAllText($cache)
  Probe $true
  if ([IO.File]::ReadAllText($cache) -ne $original) { throw 'Cache was overwritten' }
  $env:WindowsSdkDir = $null; $env:WindowsSDKVersion = $null
  Probe $false
  Remove-Item -LiteralPath $cache
  Probe $false
  if (Test-Path -LiteralPath $cache) { throw 'Missing SDK generated a corrupt cache' }
  [IO.File]::WriteAllText($cache, "CPPWINRT_INCLUDE=$include")
  Probe $true
  Remove-Item -LiteralPath $cache
  $env:CPPWINRT_INCLUDE = $include
  Probe $true
  Write-Output 'PASS: SDK environment, missing/invalid/valid cache and explicit override'
} finally {
  Pop-Location
  $env:WindowsSdkDir = $sdkDir; $env:WindowsSDKVersion = $sdkVersion
  $env:CPPWINRT_INCLUDE = $override
  foreach ($name in @('probe.mak','cppwinrt_path.mak')) {
    Remove-Item -LiteralPath (Join-Path $dir $name) -ErrorAction SilentlyContinue
  }
  [IO.Directory]::Delete($dir)
}

# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
# Run from a Visual Studio developer prompt. Cover non-LTCG optimization,
# including the codecs' /O2 /Ob3 flags, and an unoptimized control build.
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:TEMP ('7zip-lz-frame-tests-' + [guid]::NewGuid().ToString('N'))
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$common = @('tests/lz-frame.c', 'C/hashes/xxhash.c')
$codecs = @{
  lz5 = @('C/lz5/lz5.c', 'C/lz5/lz5hc.c', 'C/lz5/lz5frame.c')
  lizard = @('C/lizard/lizard_compress.c', 'C/lizard/lizard_decompress.c',
    'C/lizard/lizard_frame.c', 'C/lizard/liz_entropy_common.c',
    'C/lizard/liz_fse_compress.c', 'C/lizard/liz_fse_decompress.c',
    'C/lizard/liz_huf_compress.c', 'C/lizard/liz_huf_decompress.c',
    'C/zstd/hist.c', 'C/zstd/error_private.c')
}
[void](New-Item -ItemType Directory -Path $dir)
try {
  foreach ($codec in @('lz5', 'lizard')) {
    $sources = ($common + $codecs[$codec]) | ForEach-Object { Join-Path $root $_ }
    $defines = @()
    if ($codec -eq 'lizard') { $defines = @('/DTEST_LIZARD') }
    foreach ($optimization in @('/O1', '/O2', '/Od')) {
      Write-Host "$codec frame tests ($optimization)"
      $optimizationFlags = @($optimization)
      if ($optimization -eq '/O2') { $optimizationFlags += '/Ob3' }
      & cl /nologo $optimizationFlags /Gy /Gw /GS- /MT $defines "/I$root/C/$codec" "/Fo$dir\" "/Fe$dir/lz-frame.exe" $sources
      if ($LASTEXITCODE -ne 0) { throw "$codec compilation failed: $optimization" }
      & "$dir/lz-frame.exe"
      if ($LASTEXITCODE -ne 0) { throw "$codec frame tests failed: $optimization" }
    }
  }
} finally {
  foreach ($source in ($common + $codecs.lz5 + $codecs.lizard)) {
    $obj = [IO.Path]::GetFileNameWithoutExtension($source) + '.obj'
    Remove-Item -LiteralPath (Join-Path $dir $obj) -ErrorAction SilentlyContinue
  }
  Remove-Item -LiteralPath "$dir/lz-frame.exe" -ErrorAction SilentlyContinue
  [IO.Directory]::Delete($dir)
}

# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
# Run from a Visual Studio developer prompt. Tests never alter shell registration.
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:TEMP ('7zip-options-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $dir)
try {
  foreach ($name in @('shell-menu-transaction','assoc-command','shell-operation-wait')) {
    $exe = Join-Path $dir "$name.exe"
    $obj = Join-Path $dir "$name.obj"
    & cl /nologo /EHsc /W4 /WX "/Fo$obj" "/Fe$exe" "$PSScriptRoot/$name.cpp" user32.lib comctl32.lib
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $name" }
    & $exe
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $name" }
  }
  $sources = @('tests/registry-context-menu.cpp', 'CPP/7zip/UI/Explorer/RegistryContextMenu.cpp',
    'CPP/Windows/Registry.cpp', 'CPP/Common/MyString.cpp', 'CPP/Common/IntToString.cpp') |
    ForEach-Object { Join-Path "$PSScriptRoot/.." $_ }
  & cl /nologo /EHsc /W4 /WX /DUNICODE /D_UNICODE /DZ7_WIN32_WINNT_MIN=0x0600 /Gy "/Fo$dir\" "/Fe$dir/registry-context-menu.exe" $sources advapi32.lib user32.lib oleaut32.lib /link /OPT:REF
  if ($LASTEXITCODE -ne 0) { throw 'Registry test compilation failed' }
  & "$dir/registry-context-menu.exe"
  if ($LASTEXITCODE -ne 0) { throw 'Registry test failed' }
  & "$PSScriptRoot/check-fm-sdk.ps1"
} finally {
  foreach ($name in @('shell-menu-transaction','assoc-command','shell-operation-wait','registry-context-menu',
      'RegistryContextMenu','Registry','MyString','IntToString')) {
    foreach ($ext in @('exe','obj')) {
      Remove-Item -LiteralPath (Join-Path $dir "$name.$ext") -ErrorAction SilentlyContinue
    }
  }
  [IO.Directory]::Delete($dir)
}

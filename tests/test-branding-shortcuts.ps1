# Run from a Visual Studio developer prompt. All shortcuts live in a temporary fixture.
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('roxazip-shortcuts-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $source = Get-Content -Raw (Join-Path $PSScriptRoot '../C/Util/7zipInstall/7zipInstall.c')
    $start = $source.IndexOf('static void RemoveLegacyShellLinks(')
    $end = $source.IndexOf('#endif', $start)
    if ($start -lt 0 -or $end -lt 0) { throw 'Shortcut migration helper not found.' }
    $helper = $source.Substring($start, $end - $start)
    $harness = @'
#define COBJMACROS
#include <windows.h>
#include <shlobj.h>
#include <shlguid.h>
#include <wchar.h>
static WCHAR path[MAX_PATH];
static WCHAR fixture[MAX_PATH];
static int g_AllUsers = 1;
static void NormalizePrefix(WCHAR *s) { size_t n = wcslen(s); if (n && s[n-1] != L'\\') wcscat(s, L"\\"); }
static void CatAscii(WCHAR *s, const char *a) { size_t n = wcslen(s); while (*a) s[n++] = (WCHAR)*a++; s[n] = 0; }
static HRESULT FixtureFolder(HWND w, int folder, HANDLE token, DWORD flags, LPWSTR dest)
{
  (void)w; (void)token; (void)flags;
  wcscpy(dest, fixture);
  wcscat(dest, folder == CSIDL_COMMON_PROGRAMS ? L"\\common" : L"\\user");
  return S_OK;
}
#define SHGetFolderPathW FixtureFolder
'@
    $harness += "`n$helper`n" + @'
int wmain(int argc, wchar_t **argv)
{
  if (argc != 3) return 2;
  wcscpy(path, argv[1]); NormalizePrefix(path);
  wcscpy(fixture, argv[2]);
  if (FAILED(CoInitialize(NULL))) return 3;
  RemoveLegacyShellLinks(NULL);
  CoUninitialize();
  return 0;
}
'@
    $c = Join-Path $testRoot 'migration.c'
    # Here-strings contain literal C escapes.
    $harness = $harness.Replace('\\\\', '\\')
    Set-Content -LiteralPath $c -Value $harness -Encoding utf8
    $exe = Join-Path $testRoot 'migration.exe'
    & cl /nologo /W4 /WX /D_CRT_SECURE_NO_WARNINGS "/Fo$testRoot/migration.obj" "/Fe$exe" $c ole32.lib uuid.lib user32.lib
    if ($LASTEXITCODE -ne 0) { throw 'Shortcut migration test compilation failed.' }
    $install = Join-Path $testRoot 'install'
    $shell = New-Object -ComObject WScript.Shell
    $remove = @()
    $keep = @()
    foreach ($scope in @('common', 'user')) {
        $group = Join-Path $testRoot "$scope/7-Zip-Zstandard"
        New-Item -ItemType Directory -Path $group -Force | Out-Null
        foreach ($kind in @('fm', 'help')) {
            $name = if ($kind -eq 'fm') { '7-Zip ZS File Manager.lnk' } else { '7-Zip Help.lnk' }
            $link = Join-Path $group $name
            $matchesInstall = ($scope -eq 'common') -eq ($kind -eq 'fm')
            $targetRoot = if ($matchesInstall) { $install } else { Join-Path $testRoot 'other-install' }
            $targetName = if ($kind -eq 'fm') { '7zFM.exe' } else { '7-zip.chm' }
            $shortcut = $shell.CreateShortcut($link)
            $shortcut.TargetPath = Join-Path $targetRoot $targetName
            $shortcut.Save()
            if ($matchesInstall) { $remove += $link } else { $keep += $link }
        }
        $custom = Join-Path $group 'user-created.txt'
        Set-Content -LiteralPath $custom -Value 'Keep user content.'
        $keep += $custom
    }
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        & $exe $install $testRoot
        if ($LASTEXITCODE -ne 0) { throw 'Shortcut migration failed.' }
        foreach ($p in $remove) { if (Test-Path -LiteralPath $p) { throw "Legacy shortcut remained: $p" } }
        foreach ($p in $keep) { if (!(Test-Path -LiteralPath $p)) { throw "Unrelated file removed: $p" } }
    }
    Write-Output 'PASS: migration removes only matching legacy shortcuts; other installs and user files survive; reruns are safe.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (!$resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notlike 'roxazip-shortcuts-*') { throw 'Invalid fixture cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
exit 0

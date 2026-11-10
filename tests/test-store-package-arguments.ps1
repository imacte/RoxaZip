# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
# Exercise the workflow's native pwsh invocation without building or installing a package.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$workflow = Get-Content (Join-Path $repoRoot '.github/workflows/build.yml')
$stepStart = [Array]::IndexOf($workflow, '    - name: Build the Store packages')
if ($stepStart -lt 0) { throw 'Store packaging step not found.' }
$runStart = $stepStart + 1
while ($runStart -lt $workflow.Count -and $workflow[$runStart] -ne '      run: |') { $runStart++ }
$stepLines = [Collections.Generic.List[string]]::new()
for ($i = $runStart + 1; $i -lt $workflow.Count; $i++) {
    if ($workflow[$i].StartsWith('        ')) { $stepLines.Add($workflow[$i].Substring(8)) }
    elseif ($workflow[$i].Trim()) { break }
}
if (!$stepLines.Count) { throw 'Store packaging commands not found.' }

# Use the real parameter declaration so the probe has exactly the same binding
# rules as the packager, including its optional positional identity parameters.
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repoRoot 'RoxaZipPackage/build-store-package.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -or !$ast.ParamBlock) { throw 'Cannot parse the packager parameters.' }
$probe = $ast.ParamBlock.Extent.Text + "`n" + @'
[pscustomobject]@{
    SourceDir = $SourceDir
    Arch = $Arch
    Version = $Version
    OutDir = $OutDir
    IdentityName = $IdentityName
    Publisher = $Publisher
    PublisherDisplayName = $PublisherDisplayName
    HideHelperApps = [bool]$HideHelperApps
    Sign = [bool]$Sign
    MakeCert = [bool]$MakeCert
    Install = [bool]$Install
    RemainingArgs = @($args)
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutDir "arguments-$Arch.json")
'@

$fixtureRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('roxazip-store-args-' + [guid]::NewGuid().ToString('N'))))
$savedVersion = $env:STORE_VERSION
$savedHide = $env:STORE_HIDE_HELPERS
$savedPath = $env:PATH
$pwsh = Join-Path $PSHOME 'pwsh.exe'
try {
    foreach ($path in @('RoxaZipPackage', 'artifact/bin-x64', 'artifact/bin-arm64', 'skel', 'store')) {
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot $path) -Force | Out-Null
    }
    foreach ($arch in @('x64', 'arm64')) {
        Set-Content -LiteralPath (Join-Path $fixtureRoot "artifact/bin-$arch/RoxaZipFM.exe") -Value 'fixture'
    }
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'RoxaZipPackage/build-store-package.ps1') -Value $probe
    $stepFile = Join-Path $fixtureRoot 'store-step.ps1'
    Set-Content -LiteralPath $stepFile -Value (@('$ErrorActionPreference = ''Stop''') + $stepLines.ToArray())
    $env:STORE_VERSION = '26.6.42.0'
    $env:PATH = "$PSHOME;$savedPath"
    Push-Location $fixtureRoot
    try {
        foreach ($hide in @('1', '0')) {
            $env:STORE_HIDE_HELPERS = $hide
            & $pwsh -NoProfile -File $stepFile
            if ($LASTEXITCODE -ne 0) { throw "Store workflow failed with STORE_HIDE_HELPERS=$hide" }
            foreach ($arch in @('x64', 'arm64')) {
                $bound = Get-Content -LiteralPath "store/arguments-$arch.json" -Raw | ConvertFrom-Json
                if ($bound.IdentityName -or $bound.Publisher -or $bound.PublisherDisplayName -or $bound.RemainingArgs.Count) {
                    throw "Store workflow corrupted the identity arguments for $arch (hide=$hide)."
                }
                if ($bound.SourceDir -ne 'skel' -or $bound.Arch -ne $arch -or $bound.Version -ne $env:STORE_VERSION -or $bound.OutDir -ne 'store') {
                    throw "Store workflow changed required arguments for $arch (hide=$hide)."
                }
                if ($bound.HideHelperApps -ne ($hide -eq '1') -or $bound.Sign -or $bound.MakeCert -or $bound.Install) {
                    throw "Store workflow changed package switches for $arch (hide=$hide)."
                }
            }
            Write-Output "PASS: x64/arm64 Store argument binding, STORE_HIDE_HELPERS=$hide"
        }
    } finally { Pop-Location }
} finally {
    $env:STORE_VERSION = $savedVersion
    $env:STORE_HIDE_HELPERS = $savedHide
    $env:PATH = $savedPath
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$fixtureRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($fixtureRoot) -notmatch '^roxazip-store-args-[0-9a-f]{32}$') {
        throw 'Unexpected Store argument test directory.'
    }
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}

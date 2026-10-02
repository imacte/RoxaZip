# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactDirectory
)

$ErrorActionPreference = 'Stop'

function Invoke-Gh {
    & gh @args
    if ($LASTEXITCODE -ne 0) { throw "GitHub CLI failed: $($args[0]) $($args[1])" }
}

# Refuse a partial package even if the legacy packaging script returned success.
$versionFile = Join-Path $PSScriptRoot '../workflows/do-release.cmd'
$versionMatch = [regex]::Match((Get-Content -Raw -LiteralPath $versionFile), '(?m)^SET VERSION=([^\r\n]+)')
if (!$versionMatch.Success) { throw 'Cannot determine the package version.' }
$version = $versionMatch.Groups[1].Value.Trim()
$expected = @("RoxaZip-$version-totalcmd.7z")
foreach ($arch in @('x86', 'x64', 'arm64', 'x86-ndm', 'x64-ndm', 'arm64-ndm')) {
    $expected += "RoxaZip-$version-windows-$arch.exe", "RoxaZip-$version-codecs-$arch.7z"
}
foreach ($arch in @('x64', 'arm64')) {
    foreach ($compiler in @('gcc', 'clang')) {
        $expected += "RoxaZip-$version-linux-$arch-$compiler.tar.gz"
    }
}
$assets = @(foreach ($name in $expected) {
    $file = Get-Item -LiteralPath (Join-Path $ArtifactDirectory $name)
    if ($file.Length -eq 0) { throw "Empty release asset: $name" }
    $file.FullName
})
$checksums = Join-Path $ArtifactDirectory 'SHA256SUMS.txt'
$assets | ForEach-Object {
    $hash = Get-FileHash -LiteralPath $_ -Algorithm SHA256
    '{0}  {1}' -f $hash.Hash.ToLowerInvariant(), [IO.Path]::GetFileName($_)
} | Set-Content -LiteralPath $checksums -Encoding ascii
$assets += (Get-Item -LiteralPath $checksums).FullName

$isVersionTag = $env:GITHUB_REF -like 'refs/tags/v*'
if ($env:GITHUB_EVENT_NAME -ne 'push' -or (!$isVersionTag -and $env:GITHUB_REF -ne 'refs/heads/master')) {
    throw 'Releases are only published for master pushes or version tags.'
}
$repo = $env:GITHUB_REPOSITORY
$sha = $env:GITHUB_SHA
if (!$repo -or $sha -notmatch '^[0-9a-f]{40}$' -or $env:GITHUB_RUN_NUMBER -notmatch '^\d+$') {
    throw 'Missing or invalid GitHub Actions release context.'
}
$tag = if ($isVersionTag) { $env:GITHUB_REF.Substring(10) } else { "build-$($env:GITHUB_RUN_NUMBER)-$($sha.Substring(0, 8))" }
$title = if ($isVersionTag) { "RoxaZip $tag" } else { "RoxaZip $version - build $($env:GITHUB_RUN_NUMBER)" }
$runUrl = "$env:GITHUB_SERVER_URL/$repo/actions/runs/$env:GITHUB_RUN_ID"

# Keep uploads in a draft until all assets are present. Re-running a completed
# release leaves its published assets untouched; a failed draft can be retried.
$existingJson = & gh release view $tag --repo $repo --json isDraft,url 2>$null
if ($LASTEXITCODE -eq 0) {
    $existing = $existingJson | ConvertFrom-Json
    if (!$existing.isDraft) {
        Write-Output "Already published: $($existing.url)"
        exit 0
    }
} else {
    $kind = if ($isVersionTag) { 'Version release.' } else { 'Automated development build from master (prerelease).' }
    $notes = @"
$kind

Commit: $sha
Build and test results: $runUrl

Windows installers: x64, x86 and ARM64. Files with the -ndm suffix omit dark mode.
Codecs packages and the Total Commander plugin are included. SHA256SUMS.txt lists asset checksums.
Linux tar.gz packages: x64 and ARM64, built with GCC and Clang. Each includes RoxaZip, RoxaZipA, RoxaZipR, RoxaZipZ and RoxaZip.so with executable permissions preserved.
"@
    $notesPath = Join-Path $ArtifactDirectory 'release-notes.md'
    Set-Content -LiteralPath $notesPath -Value $notes -Encoding utf8
    $createArgs = @('release', 'create', $tag, '--repo', $repo, '--target', $sha,
        '--title', $title, '--notes-file', $notesPath, '--draft')
    if ($isVersionTag) { $createArgs += '--verify-tag' } else { $createArgs += '--prerelease' }
    Invoke-Gh @createArgs
}
Invoke-Gh release upload $tag @assets --repo $repo --clobber
$editArgs = @('release', 'edit', $tag, '--repo', $repo, '--draft=false')
if ($isVersionTag) { $editArgs += '--prerelease=false' } else { $editArgs += '--prerelease', '--latest=false' }
Invoke-Gh @editArgs
$releaseUrl = Invoke-Gh release view $tag --repo $repo --json url --jq .url
Write-Output "Published: $releaseUrl"
if ($env:GITHUB_STEP_SUMMARY) {
    "Published [$title]($releaseUrl) with $($assets.Count) assets." | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
}

# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactDirectory
)

$ErrorActionPreference = 'Stop'

function Invoke-Gh {
    $command = $args -join ' '
    Write-Output "+ gh $command"
    & gh @args
    if ($LASTEXITCODE -ne 0) { throw "GitHub CLI failed (exit $LASTEXITCODE): gh $command" }
}

# The uploads are large (about 130 MB), so a transient failure is retried instead
# of leaving a draft release behind.
function Send-ReleaseAssets {
    param([string]$Tag, [string[]]$Files, [string]$Repo)
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Invoke-Gh release upload $Tag @Files --repo $Repo --clobber
            return
        }
        catch {
            Write-Output "upload attempt $attempt failed: $($_.Exception.Message)"
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds 10
        }
    }
}

try { Write-Output "gh: $(& gh --version | Select-Object -First 1)" }
catch { Write-Output "gh: version unknown" }

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
Write-Output "version      : $version"
Write-Output "release tag  : $tag"
Write-Output "assets       : $($assets.Count) (incl. SHA256SUMS.txt) from $ArtifactDirectory"

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
Send-ReleaseAssets -Tag $tag -Files $assets -Repo $repo
$editArgs = @('release', 'edit', $tag, '--repo', $repo, '--draft=false')
if ($isVersionTag) { $editArgs += '--prerelease=false' } else { $editArgs += '--prerelease', '--latest=false' }
Invoke-Gh @editArgs
$stateJson = & gh release view $tag --repo $repo --json isDraft,url
if ($LASTEXITCODE -ne 0) { throw "cannot read back the release: $tag" }
$state = $stateJson | ConvertFrom-Json
if ($state.isDraft) { throw "the release $tag is still a draft after publishing" }
$releaseUrl = $state.url
Write-Output "Published: $releaseUrl"
if ($env:GITHUB_STEP_SUMMARY) {
    "Published [$title]($releaseUrl) with $($assets.Count) assets." | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
}

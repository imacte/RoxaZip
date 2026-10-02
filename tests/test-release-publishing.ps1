$ErrorActionPreference = 'Stop'
$publisher = Join-Path $PSScriptRoot '../.github/scripts/publish-release.ps1'
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('7zip-release-test-' + [guid]::NewGuid())
$fixture = New-Item -ItemType Directory -Path $fixtureRoot
$savedEnv = @{}
$testEnv = @{
    GITHUB_EVENT_NAME = 'push'
    GITHUB_REF = 'refs/heads/master'
    GITHUB_REPOSITORY = 'test/repo'
    GITHUB_SHA = ('a' * 40)
    GITHUB_RUN_NUMBER = '42'
    GITHUB_RUN_ID = '123'
    GITHUB_SERVER_URL = 'https://github.com'
    GITHUB_STEP_SUMMARY = ''
}
foreach ($key in $testEnv.Keys) {
    $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key)
    [Environment]::SetEnvironmentVariable($key, $testEnv[$key])
}

# Mock the external CLI: these tests never contact GitHub or publish anything.
$releaseTestContext = @{ Calls = [Collections.Generic.List[object]]::new(); State = 'new' }
$releaseTestContext.State = 'new'
function gh {
    $releaseTestContext.Calls.Add(@($args))
    $global:LASTEXITCODE = 0
    switch ($args[1]) {
        'view' {
            if ($args -contains '--jq') { return 'https://github.com/test/repo/releases/tag/test' }
            if ($releaseTestContext.State -eq 'new' -or $releaseTestContext.State -eq 'upload-failure') {
                $global:LASTEXITCODE = 1
                return
            }
            return (@{ isDraft = ($releaseTestContext.State -eq 'draft'); url = 'https://example.test/release' } | ConvertTo-Json -Compress)
        }
        'upload' {
            if ($releaseTestContext.State -eq 'upload-failure') { $global:LASTEXITCODE = 1 }
        }
    }
}
function Assert($condition, [string]$message) {
    if (!$condition) { throw $message }
}
function Run-Publisher {
    $releaseTestContext.Calls.Clear()
    & $publisher -ArtifactDirectory $fixture.FullName
}
function Assert-Rejected {
    $rejected = $false
    try { Run-Publisher } catch { $rejected = $true }
    Assert $rejected 'Expected publishing to fail.'
}

try {
    $packageScript = Get-Content -Raw (Join-Path $PSScriptRoot '../.github/workflows/do-release.cmd')
    $version = [regex]::Match($packageScript, '(?m)^SET VERSION=([^\r\n]+)').Groups[1].Value.Trim()
    Set-Content (Join-Path $fixture "RoxaZip-$version-totalcmd.7z") 'test fixture'
    foreach ($arch in @('x86', 'x64', 'arm64', 'x86-ndm', 'x64-ndm', 'arm64-ndm')) {
        Set-Content (Join-Path $fixture "RoxaZip-$version-windows-$arch.exe") 'test fixture'
        Set-Content (Join-Path $fixture "RoxaZip-$version-codecs-$arch.7z") 'test fixture'
    }
    foreach ($arch in @('x64', 'arm64')) {
        foreach ($compiler in @('gcc', 'clang')) {
            Set-Content (Join-Path $fixture "RoxaZip-$version-linux-$arch-$compiler.tar.gz") 'test fixture'
        }
    }

    Run-Publisher
    $create = $releaseTestContext.Calls | Where-Object { $_[1] -eq 'create' }
    Assert ($create -contains '--draft') 'Assets must be uploaded before publication.'
    Assert ($create -contains '--prerelease') 'Master must create a prerelease.'
    Assert ($create -contains 'build-42-aaaaaaaa') 'Development tag must identify the build and commit.'
    $upload = $releaseTestContext.Calls | Where-Object { $_[1] -eq 'upload' }
    Assert (@($upload | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -eq 18) 'Expected 17 Windows/Linux packages and a checksum file.'
    Assert (@(Get-Content (Join-Path $fixture 'SHA256SUMS.txt')).Count -eq 17) 'Checksums must cover all packages.'
    Assert ($releaseTestContext.Calls[3][1] -eq 'edit') 'Publication must follow upload.'
    Assert ($releaseTestContext.Calls[3] -contains '--latest=false') 'Development builds must not become the latest stable release.'
    Write-Output 'PASS: master prerelease and asset checksums'

    $env:GITHUB_REF = 'refs/tags/v26.03-test'
    Run-Publisher
    $create = $releaseTestContext.Calls | Where-Object { $_[1] -eq 'create' }
    Assert ($create -contains '--verify-tag') 'Stable release must require the existing version tag.'
    Assert ($create -notcontains '--prerelease') 'Version tags must produce stable releases.'
    Assert ($releaseTestContext.Calls[3] -contains '--prerelease=false') 'Stable release must clear the prerelease flag.'
    Write-Output 'PASS: version-tag release'

    $env:GITHUB_REF = 'refs/heads/master'
    $releaseTestContext.State = 'draft'
    Run-Publisher
    Assert ($releaseTestContext.Calls.Count -eq 4) 'Draft retries must reuse the release.'
    Assert ($releaseTestContext.Calls[1][1] -eq 'upload') 'Draft retries must resume uploading.'
    Write-Output 'PASS: interrupted draft retry'

    $releaseTestContext.State = 'published'
    Run-Publisher
    Assert ($releaseTestContext.Calls.Count -eq 1) 'Published releases must not be overwritten on retry.'
    Write-Output 'PASS: published release retry'

    $releaseTestContext.State = 'upload-failure'
    Assert-Rejected
    Assert (@($releaseTestContext.Calls | Where-Object { $_[1] -eq 'edit' }).Count -eq 0) 'Failed uploads must leave the release unpublished.'
    Write-Output 'PASS: failed upload cannot publish'

    $env:GITHUB_EVENT_NAME = 'pull_request'
    Assert-Rejected
    Assert ($releaseTestContext.Calls.Count -eq 0) 'Pull requests must not call GitHub.'
    $env:GITHUB_EVENT_NAME = 'push'
    $env:GITHUB_REF = 'refs/heads/feature'
    Assert-Rejected
    Assert ($releaseTestContext.Calls.Count -eq 0) 'Feature branches must not call GitHub.'
    $env:GITHUB_REF = 'refs/heads/master'
    Write-Output 'PASS: pull request and branch guards'

    foreach ($arch in @('x64', 'arm64')) {
        foreach ($compiler in @('gcc', 'clang')) {
            $linuxPackage = Join-Path $fixture "RoxaZip-$version-linux-$arch-$compiler.tar.gz"
            Remove-Item -LiteralPath $linuxPackage
            Assert-Rejected
            Assert ($releaseTestContext.Calls.Count -eq 0) 'Missing Linux packages must fail before contacting GitHub.'
            Set-Content -LiteralPath $linuxPackage 'test fixture'
        }
    }
    Write-Output 'PASS: all four Linux packages are required'

    Set-Content -LiteralPath (Join-Path $fixture "RoxaZip-$version-totalcmd.7z") -Value '' -NoNewline
    Assert-Rejected
    Assert ($releaseTestContext.Calls.Count -eq 0) 'Empty packages must fail before contacting GitHub.'
    Remove-Item -LiteralPath (Join-Path $fixture "RoxaZip-$version-totalcmd.7z")
    Assert-Rejected
    Assert ($releaseTestContext.Calls.Count -eq 0) 'Missing packages must fail before contacting GitHub.'
    Write-Output 'PASS: empty and missing package guards'
} finally {
    foreach ($key in $savedEnv.Keys) {
        [Environment]::SetEnvironmentVariable($key, $savedEnv[$key])
    }
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (!$resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolved) -notlike '7zip-release-test-*') {
        throw 'Refusing to clean up a fixture outside the expected temporary directory.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

# GitHub's pwsh wrapper propagates LASTEXITCODE. Successful negative tests must
# not leak the simulated GitHub CLI failure into the step's final exit status.
exit 0

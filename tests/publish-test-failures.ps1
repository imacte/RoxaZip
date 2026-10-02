# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
# publish-test-failures.ps1 --
#
# Part of 7-Zip ZS test suite.
#
# Turns the failures of a captured tcltest log into GitHub Actions annotations
# (workflow commands), so a failing test is visible in the public check run and
# not only in the authenticated job log -- same idea as the compiler problem
# matchers in .github. Uses the log captured by the "Test" steps.
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/publish-test-failures.ps1 -LogPath <file>
#
# The exit code of the test run is not changed here, the caller keeps it.

param(
  # Captured output of "tclsh tests/7z-test.tcl -verbose tsem":
  [Parameter(Mandatory = $true)][string]$LogPath,
  # GitHub drops annotations of a check run beyond a small limit:
  [int]$MaxAnnotations = 20,
  [int]$MaxMessageLength = 1200
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LogPath)) { throw "Test log not found: $LogPath" }

# The log is a console redirect, so decode the bytes without assuming a code page
# (tcltest escapes non-ASCII itself, everything else is passed through unchanged):
$lines = [IO.File]::ReadAllText($LogPath, [Text.Encoding]::GetEncoding(28591)) -split "\r?\n"

function ConvertTo-AnnotationData([string]$Value) {
  # https://docs.github.com/actions/reference/workflow-commands-for-github-actions
  $Value.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
}

function Get-LogTail([string[]]$Lines, [int]$Length) {
  $tail = ($Lines | Where-Object { $_ -ne '' } | Select-Object -Last 12) -join "`n"
  if ($tail.Length -gt $Length) { $tail = $tail.Substring($tail.Length - $Length) }
  $tail
}

$testFile = ''
$failures = New-Object System.Collections.Generic.List[object]
$summary = ''

for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i]

  # tcltest prints the name of the sourced test file before its tests:
  if ($line -match '^[A-Za-z0-9_.-]+\.test$') { $testFile = $line; continue }
  # "... 7z-test.tcl:	Total	46	Passed	37	Skipped	1	Failed	8":
  if ($line -match '^\S+\.tcl:\s+Total\s') { $summary = $line.Trim(); continue }

  if ($line -match '^==== (\S+) (.*?) FAILED$') {
    $name = $Matches[1]
    $desc = $Matches[2]
    $endMarker = "==== $name FAILED"
    $details = New-Object System.Collections.Generic.List[string]
    for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j] -ne $endMarker; $j++) {
      $details.Add($lines[$j])
    }
    $i = [Math]::Min($j, $lines.Count - 1)
    # trim empty edges of the detail block:
    while ($details.Count -gt 0 -and $details[0].Trim() -eq '') { $details.RemoveAt(0) }
    while ($details.Count -gt 0 -and $details[$details.Count - 1].Trim() -eq '') { $details.RemoveAt($details.Count - 1) }
    $message = (@($desc) + @($details)) -join "`n"
    if ($message.Length -gt $MaxMessageLength) { $message = $message.Substring(0, $MaxMessageLength) + ' ...' }
    $failures.Add([pscustomobject]@{ Name = $name; File = $testFile; Message = $message })
  }
}

foreach ($failure in ($failures | Select-Object -First $MaxAnnotations)) {
  $properties = ''
  if ($failure.File) { $properties += "file=tests/$($failure.File)," }
  $properties += "title=$($failure.Name)"
  Write-Output "::error $properties`::$((ConvertTo-AnnotationData $failure.Message))"
}

if ($failures.Count -gt $MaxAnnotations) {
  Write-Output "::warning title=tcltest::$($failures.Count - $MaxAnnotations) more failure(s) are only in the job log"
}

if ($summary) {
  $text = $summary
  if ($failures.Count -gt 0) {
    $names = ($failures | Select-Object -ExpandProperty Name) -join ', '
    $text += " ($names)"
  }
  Write-Output "::notice title=tcltest::$((ConvertTo-AnnotationData $text))"
}
elseif ($failures.Count -eq 0) {
  # No tcltest summary and no parsed failure: the suite aborted early (missing
  # interpreter, unrunnable binary, ...), which must not stay log-only either:
  Write-Output "::error title=tcltest::no test summary in the log, tail: $((ConvertTo-AnnotationData (Get-LogTail $lines $MaxMessageLength)))"
}

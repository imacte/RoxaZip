<#
  RoxaZip - add this fork's own file manager strings to the shipped language files.

  The file manager reads its texts from "<program dir>\Lang\<id>.txt"; those files
  are upstream 7-Zip files that arrive with the upstream installer and therefore
  cannot contain the strings this fork adds (Help -> Check for updates, and the
  other RoxaZip-only texts). For everything a language file does not have, the
  program falls back to the English string table inside RoxaZipFM.exe, so a
  language is translated by merging the matching file of
  .github/scripts/lang-additions\ into its language file at packaging time.

  The numeric IDs must stay ascending, and CLang (CPP/Common/Lang.cpp) derives
  the ID of every text line from the order (a lone number sets the ID, comments
  and empty lines increment it), so the entries are inserted at the position
  their ID requires instead of being appended. Running the script twice is safe:
  an entry that is already in the file is replaced.

  Usage:
    pwsh -NoProfile -File .github/scripts/apply-lang-additions.ps1 -LangDir <dir>
    pwsh -NoProfile -File .github/scripts/apply-lang-additions.ps1 -LangDir Lang -Check

  -Check only verifies that every entry is present with the expected text (it
  writes nothing); the packaging uses it to make sure the committed Lang\ folder
  was refreshed after its entries changed. Called by build-store-package.ps1 (the
  Store package) and by .github/workflows/do-release.cmd (the classic installer
  payload); RoxaZipPackage/update-upstream-lang.ps1 uses the merge to refresh the
  committed folder.
#>
param(
  [Parameter(Mandatory = $true)][string]$LangDir,
  [string]$AdditionsDir,
  [switch]$Check
)

$ErrorActionPreference = 'Stop'

$signature = ';!@Lang2@!UTF-8!'
if (-not $AdditionsDir) { $AdditionsDir = Join-Path $PSScriptRoot 'lang-additions' }
if (-not (Test-Path -LiteralPath $LangDir)) { throw "no language directory: $LangDir" }
if (-not (Test-Path -LiteralPath $AdditionsDir)) { throw "no additions directory: $AdditionsDir" }

function Read-LangLines([string]$path)
{
  $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($path))
  if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
  return @($text -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
}

# The same walk as CLang::OpenFromString: one text line is one entry, a lone
# number sets the ID for the lines that follow, comments/empty lines increment.
function Get-LangEntries([string[]]$lines, [string]$what)
{
  if ($lines.Count -lt 2 -or $lines[0] -ne $signature) { throw "$what is not a 7-Zip language file (missing $signature)" }

  $id = -1024
  $list = New-Object System.Collections.ArrayList
  for ($i = 1; $i -lt $lines.Count; $i++)
  {
    $line = $lines[$i]
    $trimmed = $line.Trim()
    if ($trimmed -eq '' -or $trimmed.StartsWith(';')) { $id++; continue }

    $num = 0
    if ($trimmed -match '^\d+$') { $num = [int]$trimmed; $id = $num; continue }

    if ($id -lt 0) { throw "$what assigns an ID before the first number (line $($i + 1))" }
    [void]$list.Add([pscustomobject]@{ Index = $i; ID = [int]$id; Text = $line })
    $id++
  }
  return $list.ToArray()
}

# line index where an entry with this ID has to go: before the first line that
# must come after it (a number larger than the ID, or a text line that would
# take the ID or a later one). $lines.Count means "at the end".
function Get-InsertIndex([string[]]$lines, [int]$newID)
{
  $id = -1024
  for ($i = 1; $i -lt $lines.Count; $i++)
  {
    $trimmed = $lines[$i].Trim()
    if ($trimmed -eq '' -or $trimmed.StartsWith(';')) { $id++; continue }
    if ($trimmed -match '^\d+$')
    {
      $num = [int]$trimmed
      if ($num -gt $newID) { return $i }
      $id = $num
      continue
    }
    if ($id -ge $newID) { return $i }
    $id++
  }
  return $lines.Count
}

$summary = New-Object System.Collections.ArrayList
$fragments = @(Get-ChildItem -LiteralPath $AdditionsDir -Filter '*.txt' -File | Sort-Object Name)
if ($fragments.Count -eq 0) { throw "no language additions in $AdditionsDir" }

foreach ($fragment in $fragments)
{
  $target = Join-Path $LangDir $fragment.Name
  if (-not (Test-Path -LiteralPath $target))
  {
    if ($Check) { throw "$($fragment.Name): the language file is missing from $LangDir" }
    [void]$summary.Add("$($fragment.Name): no such language file, skipped")
    continue
  }

  $lines = Read-LangLines $target
  $entries = Get-LangEntries $lines "$($fragment.Name) target"
  $have = @{}
  foreach ($e in $entries) { $have[$e.ID] = $e }

  $additions = Get-LangEntries (Read-LangLines $fragment.FullName) "$($fragment.Name) additions"

  if ($Check)
  {
    $wrong = New-Object System.Collections.ArrayList
    foreach ($a in $additions)
    {
      if (-not $have.ContainsKey($a.ID) -or $have[$a.ID].Text -ne $a.Text) { [void]$wrong.Add($a.ID) }
    }
    if ($wrong.Count -ne 0)
    {
      throw "$($fragment.Name): $($wrong.Count) of $($additions.Count) entries are missing or different (IDs $($wrong -join ', ')) - run .github/scripts/update-upstream-lang.ps1 after refreshing the language file"
    }
    [void]$summary.Add("$($fragment.Name): all $($additions.Count) entries are present")
    continue
  }

  $insertAt = @{}
  $replace = @{}
  $added = 0
  $replaced = 0

  foreach ($a in $additions)
  {
    if ($have.ContainsKey($a.ID))
    {
      $replace[$have[$a.ID].Index] = $a.Text
      $replaced++
      continue
    }
    $pos = Get-InsertIndex $lines $a.ID
    if (-not $insertAt.ContainsKey($pos)) { $insertAt[$pos] = New-Object System.Collections.ArrayList }
    [void]$insertAt[$pos].Add($a)
    $added++
  }

  if ($added -eq 0 -and $replaced -eq 0)
  {
    [void]$summary.Add("$($fragment.Name): nothing to do")
    continue
  }

  $crlf = ([IO.File]::ReadAllText($target)).Contains("`r`n")
  $out = New-Object System.Collections.ArrayList
  for ($i = 0; $i -le $lines.Count; $i++)
  {
    if ($insertAt.ContainsKey($i))
    {
      foreach ($a in ($insertAt[$i] | Sort-Object ID))
      {
        [void]$out.Add([string]$a.ID)
        [void]$out.Add([string]$a.Text)
      }
    }
    if ($i -lt $lines.Count)
    {
      if ($replace.ContainsKey($i)) { [void]$out.Add([string]$replace[$i]) }
      else { [void]$out.Add([string]$lines[$i]) }
    }
  }

  $newText = ($out -join "`n")
  if (-not $newText.EndsWith("`n")) { $newText += "`n" }
  if ($crlf) { $newText = $newText -replace "`n", "`r`n" }
  [IO.File]::WriteAllText($target, $newText, (New-Object Text.UTF8Encoding($false)))

  # re-read the result: the IDs must still be ascending and ours must be there
  # (not "$check": a script parameter of that name is case-insensitively the
  # same variable and would reject the array)
  $result = Get-LangEntries (Read-LangLines $target) "$($fragment.Name) result"
  $seen = @{}
  $last = -1
  foreach ($e in $result)
  {
    if ($e.ID -le $last) { throw "$($fragment.Name): the IDs are not ascending after the merge (id $($e.ID))" }
    $last = $e.ID
    $seen[$e.ID] = $e.Text
  }
  foreach ($a in $additions)
  {
    if (-not $seen.ContainsKey($a.ID) -or $seen[$a.ID] -ne $a.Text)
    {
      throw "$($fragment.Name): entry $($a.ID) is missing or different after the merge"
    }
  }

  [void]$summary.Add("$($fragment.Name): $added added, $replaced replaced (highest ID now $last)")
}

$summary | ForEach-Object { Write-Output $_ }

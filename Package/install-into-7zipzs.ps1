<#
  RoxaZip - copy the freshly built binaries into the installation directory.

  Run this with administrator rights (the script elevates itself if needed):

      pwsh -File Package\install-into-7zipzs.ps1
      pwsh -File Package\install-into-7zipzs.ps1 -InstallDir "C:\Program Files\7-Zip-Zstandard"

  Build the binaries first, for example:

      nmake PLATFORM=x64                 (in CPP\7zip\Bundles\Fm)          -> 7zFM.exe
      nmake PLATFORM=x64                 (in CPP\7zip\UI\GUI)              -> 7zG.exe
      nmake PLATFORM=x64                 (in CPP\7zip\Bundles\Alone2)      -> 7zz.exe
      nmake PLATFORM=x64                 (in CPP\7zip\Bundles\Format7zF)   -> 7z.dll
      nmake PLATFORM=x64                 (in CPP\7zip\UI\Explorer)         -> 7-zip.dll
#>
param(
  [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
  [string]$InstallDir = 'D:\Program Files\7-Zip-Zstandard',
  [switch]$NoExplorerRestart,
  [string]$LogFile
)

$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "  $m" }

if (-not $LogFile) { $LogFile = Join-Path $PSScriptRoot 'Output\install-into-7zipzs.log' }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin)
{
  Write-Host 'Restarting with administrator rights (UAC) ...'
  $logDir = Split-Path $LogFile -Parent
  if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
  Remove-Item $LogFile -Force -ErrorAction SilentlyContinue

  $exe = (Get-Process -Id $PID).Path
  # quoted argument string: paths may contain spaces ("Program Files")
  $argLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -RepoRoot "{1}" -InstallDir "{2}" -LogFile "{3}"' -f `
    $PSCommandPath, $RepoRoot, $InstallDir, $LogFile
  if ($NoExplorerRestart) { $argLine += ' -NoExplorerRestart' }

  $p = Start-Process -FilePath $exe -ArgumentList $argLine -Verb RunAs -Wait -PassThru
  if (Test-Path $LogFile) { Get-Content $LogFile | ForEach-Object { Write-Host $_ } }
  exit $p.ExitCode
}

Start-Transcript -Path $LogFile -Force | Out-Null

if (-not (Test-Path (Join-Path $InstallDir '7zFM.exe')))
{
  Write-Host "ERROR: not an RoxaZip installation: $InstallDir" -ForegroundColor Red
  exit 2
}

$files = @(
  @{ Src = 'CPP\7zip\Bundles\Fm\x64\7zFM.exe';       Dst = '7zFM.exe' },
  @{ Src = 'CPP\7zip\UI\GUI\x64\7zG.exe';            Dst = '7zG.exe' },
  @{ Src = 'CPP\7zip\Bundles\Alone2\x64\7zz.exe';    Dst = '7zz.exe' },
  @{ Src = 'CPP\7zip\Bundles\Format7zF\x64\7z.dll';  Dst = '7z.dll' },
  # the shell extension is loaded by explorer.exe -> it is renamed before the copy
  @{ Src = 'CPP\7zip\UI\Explorer\x64\7-zip.dll';     Dst = '7-zip.dll' }
)

# close the applications that would lock the files
Stop-Process -Name 7zFM, 7zG -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

foreach ($f in $files)
{
  $src = Join-Path $RepoRoot $f.Src
  $dst = Join-Path $InstallDir $f.Dst
  if (-not (Test-Path $src))
  {
    Info "SKIP   $($f.Dst)  (not built: $($f.Src))"
    continue
  }

  if ($f.Dst -eq '7-zip.dll')
  {
    $bak = Join-Path $InstallDir ("7-zip.dll.orig-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    try { Rename-Item -Path $dst -NewName (Split-Path $bak -Leaf) -ErrorAction Stop; Info "renamed $($f.Dst) -> $(Split-Path $bak -Leaf)" }
    catch { Info "WARN   could not rename the loaded $($f.Dst): $($_.Exception.Message)" }
  }

  try
  {
    Copy-Item $src $dst -Force -ErrorAction Stop
    Info ("OK     {0,-11} {1,9} bytes  sha={2}" -f $f.Dst, (Get-Item $dst).Length,
      (Get-FileHash $dst -Algorithm SHA256).Hash.Substring(0, 16))
  }
  catch { Info "FAIL   $($f.Dst) : $($_.Exception.Message)" }
}

# The packaged COM server runs inside a dllhost.exe surrogate. A surrogate that
# is still alive keeps the OLD 7-zip.dll mapped and keeps serving the shell, so
# replacing the file and restarting Explorer is not enough - without this step
# the new build only shows up after a reboot (it looks like "the change did
# nothing").
$dllDst = Join-Path $InstallDir '7-zip.dll'
$stale = @()
Get-Process dllhost -ErrorAction SilentlyContinue | ForEach-Object {
  $proc = $_
  try
  {
    foreach ($m in $proc.Modules)
    {
      if ($m.FileName -eq $dllDst) { $stale += $proc.Id; break }
    }
  }
  catch {}
}
foreach ($stalePid in $stale)
{
  try { Stop-Process -Id $stalePid -Force -ErrorAction Stop; Info "killed stale COM surrogate dllhost pid=$stalePid (had the old 7-zip.dll)" }
  catch { Info "WARN   could not stop dllhost pid=$stalePid : $($_.Exception.Message)" }
}

if (-not $NoExplorerRestart)
{
  Write-Host '  restarting File Explorer so the new shell extension is loaded ...'
  Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
  Info 'File Explorer restarted'
}

# The sparse package manifest references Assets\*.png; for a sparse package those
# files are resolved from the *external location*, so they have to be deployed
# next to the binaries (Windows would register a layout without the logos
# otherwise, which can keep the command out of the modern context menu).
$assetsSrc = Join-Path $PSScriptRoot 'Assets'
$assetsDst = Join-Path $InstallDir 'Assets'
if (Test-Path $assetsSrc)
{
  if (-not (Test-Path $assetsDst)) { New-Item -ItemType Directory -Path $assetsDst | Out-Null }
  Copy-Item (Join-Path $assetsSrc '*.png') $assetsDst -Force
  Info ("OK     Assets\  -> {0} ({1} file(s))" -f $assetsDst, (Get-ChildItem $assetsDst -Filter *.png | Measure-Object).Count)
}

# The options page ("RoxaZip") registers the sparse package of the Windows 11
# context menu itself, so the .msix has to be next to the binaries; the program
# directory is where it looks for SevenZipZS.ShellExtension*.msix.
$msix = Get-ChildItem (Join-Path $PSScriptRoot 'Output\*.msix') -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($msix)
{
  Copy-Item $msix.FullName (Join-Path $InstallDir $msix.Name) -Force
  Info "OK     $($msix.Name) -> $InstallDir  (used by the options page)"
}
else
{
  Info 'WARN   no .msix in Package\Output - run build-shell-package.ps1, otherwise the options page cannot install the Windows 11 menu'
}

# The options page ("System" tab) can open the app's own page in the Windows
# "Default apps" settings - that needs the HKLM\SOFTWARE\RegisteredApplications
# entry, which is written here (we are already elevated).
$capScript = Join-Path $PSScriptRoot 'register-app-capabilities.ps1'
if (Test-Path $capScript)
{
  Write-Host '  registering the application for the "Default apps" settings ...'
  & $capScript
}
else { Info 'WARN   register-app-capabilities.ps1 not found' }

Write-Host 'Done.' -ForegroundColor Green

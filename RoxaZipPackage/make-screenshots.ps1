# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
<#
  RoxaZip - capture the Store listing screenshots from the running program.

  The script starts the file manager and its dialogs, resizes the windows to a
  size the Store accepts (1366x768 or larger) and writes PNG files into
  RoxaZipPackage\Screenshots.

  It cannot capture the Windows 11 context menu entry (that needs a real
  right-click), so that screenshot stays manual - see StoreListing.md.

  Examples:
    pwsh -File RoxaZipPackage\make-screenshots.ps1
    pwsh -File RoxaZipPackage\make-screenshots.ps1 -ExeDir 'D:\Program Files\RoxaZip'
#>
param(
  # directory with RoxaZipFM.exe, RoxaZipG.exe, RoxaZip.exe, RoxaZip.dll
  [string]$ExeDir,
  [string]$OutDir,
  [int]$Width = 1600,
  [int]$Height = 1000
)

$ErrorActionPreference = 'Stop'
$pkgDir = $PSScriptRoot
if (-not $ExeDir) { $ExeDir = Join-Path (Split-Path $pkgDir -Parent) 'build\bin-x64-ndm' }
if (-not $OutDir) { $OutDir = Join-Path $pkgDir 'Screenshots' }
if (-not (Test-Path (Join-Path $ExeDir 'RoxaZipFM.exe'))) { throw "no RoxaZipFM.exe in $ExeDir" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

Add-Type -AssemblyName System.Drawing

function Info($m) { Write-Host "  $m" }
function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class RoxaWin
{
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

  public static IntPtr Find(uint pid, string cls)
  {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p != pid || !IsWindowVisible(h)) return true;
      var c = new StringBuilder(128); GetClassName(h, c, 128);
      if (cls == null || c.ToString() == cls) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }

  public static string Title(IntPtr h)
  {
    var t = new StringBuilder(512); GetWindowText(h, t, 512); return t.ToString();
  }

  public static void Resize(IntPtr h, int x, int y, int width, int height)
  {
    SetWindowPos(h, IntPtr.Zero, x, y, width, height, 0x0004 /*NOZORDER*/ | 0x0040 /*SHOWWINDOW*/);
  }
}
"@

# --------------------------------------------------------------- demo files ---
Step "Preparing the demo data"
# A path that looks like a normal user folder in the screenshots (the title bar
# shows it); it is removed again at the end.
$demo = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'RoxaZip demo'
Remove-Item $demo -Recurse -Force -ErrorAction SilentlyContinue
$src = Join-Path $demo 'project'
New-Item -ItemType Directory -Path (Join-Path $src 'docs') -Force | Out-Null
Set-Content (Join-Path $src 'readme.txt') "RoxaZip demo`r`n1. compress`r`n2. extract`r`n"
Set-Content (Join-Path $src 'notes.md') "# Notes`r`n`r`nZstandard, LZ4, BLAKE3.`r`n"
Set-Content (Join-Path $src 'docs\manual.txt') ("RoxaZip manual.`r`n" * 40)
$random = New-Object Random 7
$bytes = New-Object byte[] 40960
$random.NextBytes($bytes)
[IO.File]::WriteAllBytes((Join-Path $src 'data.bin'), $bytes)
$archive = Join-Path $demo 'project.7z'
# add the contents (not the folder) so the archive shows several entries
Push-Location $src
& (Join-Path $ExeDir 'RoxaZip.exe') a -bso0 -bsp0 $archive '*' | Out-Null
Pop-Location
Info "demo archive : $archive"

$shots = @()
function Save-Shot($hwnd, $file, $resize = $false)
{
  $path = Join-Path $OutDir $file
  if ($resize)
  {
    [RoxaWin]::Resize($hwnd, 40, 40, $Width, $Height)
    Start-Sleep -Milliseconds 900
  }
  $r = New-Object RoxaWin+RECT
  if (-not [RoxaWin]::GetWindowRect($hwnd, [ref]$r)) { Info "skipped: $file (no window rect)"; return }
  $w = $r.Right - $r.Left
  $h = $r.Bottom - $r.Top
  if ($w -lt 64 -or $h -lt 64) { Info "skipped: $file (window too small)"; return }
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $hdc = $g.GetHdc()
  $ok = [RoxaWin]::PrintWindow($hwnd, $hdc, 2)
  $g.ReleaseHdc($hdc)
  if (-not $ok)
  {
    # a window that refuses PrintWindow has to be captured from the screen
    [void][RoxaWin]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 600
    $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  }
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Info ("saved  : {0}  {1}x{2}  {3:N0} bytes" -f $file, $w, $h, (Get-Item $path).Length)
  $script:shots += $file
}
# The dialogs are smaller than the size the Store wants (1366x768), so they are
# captured together with the window they belong to: the region of the file
# manager is grabbed from the screen while the dialog sits on top of it.
function Save-Region($hwnd, $file)
{
  $path = Join-Path $OutDir $file
  $r = New-Object RoxaWin+RECT
  if (-not [RoxaWin]::GetWindowRect($hwnd, [ref]$r)) { Info "skipped: $file (no window rect)"; return }
  $w = $r.Right - $r.Left
  $h = $r.Bottom - $r.Top
  if ($w -lt 64 -or $h -lt 64) { Info "skipped: $file (region too small)"; return }
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)))
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Info ("saved  : {0}  {1}x{2}  {3:N0} bytes" -f $file, $w, $h, (Get-Item $path).Length)
  $script:shots += $file
}
function Close-All($p)
{
  if ($p -and -not $p.HasExited)
  {
    [void][RoxaWin]::PostMessage($p.MainWindowHandle, 0x10, [IntPtr]::Zero, [IntPtr]::Zero)
    if (-not $p.WaitForExit(2000)) { Stop-Process -Id $p.Id -Force }
  }
}
function Wait-Window($processId, $cls, $seconds = 15)
{
  for ($i = 0; $i -lt ($seconds * 4); $i++)
  {
    $h = [RoxaWin]::Find([uint32]$processId, $cls)
    if ($h -ne [IntPtr]::Zero) { return $h }
    Start-Sleep -Milliseconds 250
  }
  return [IntPtr]::Zero
}
Get-Process RoxaZipFM, RoxaZipG -ErrorAction SilentlyContinue | Stop-Process -Force

# ----------------------------------------------------------- file manager ----
Step "File manager with an open archive"
$fm = Start-Process (Join-Path $ExeDir 'RoxaZipFM.exe') ("`"" + $archive + "`"") -PassThru
$h = Wait-Window $fm.Id '7-Zip::FM'
if ($h -ne [IntPtr]::Zero) { Save-Shot $h '01-file-manager.png' $true }
else { Info 'file manager window not found' }
Close-All $fm
Start-Sleep -Seconds 1

# --------------------------------------------------------------- options -----
Step "Options - RoxaZip page"
$fm = Start-Process (Join-Path $ExeDir 'RoxaZipFM.exe') -PassThru
$h = Wait-Window $fm.Id '7-Zip::FM'
if ($h -ne [IntPtr]::Zero)
{
  [RoxaWin]::Resize($h, 40, 40, $Width, $Height)
  Start-Sleep -Milliseconds 900
  [void][RoxaWin]::PostMessage($h, 0x111, [IntPtr]900, [IntPtr]::Zero)   # IDM_OPTIONS
  $dlg = Wait-Window $fm.Id '#32770'
  if ($dlg -ne [IntPtr]::Zero)
  {
    [void][RoxaWin]::SendMessage($dlg, 0x465, [IntPtr]1, [IntPtr]::Zero) # select the RoxaZip tab
    Start-Sleep -Milliseconds 900
    Save-Region $h '02-options-roxazip.png'      # the dialog is on top of it
  }
  else { Info 'options dialog not found' }
}
Close-All $fm
Start-Sleep -Seconds 1

# ------------------------------------------------------- add to archive ------
# The compress/hash dialogs belong to RoxaZipG.exe, which the file manager starts
# itself, so both windows are shown at once: the manager keeps its 1600x1000 size
# and the dialog appears in front of it.
function Save-Dialog-Over-Manager($file, $guiArgs)
{
  $fm = Start-Process (Join-Path $ExeDir 'RoxaZipFM.exe') ("`"" + $archive + "`"") -PassThru
  $fmH = Wait-Window $fm.Id '7-Zip::FM'
  if ($fmH -eq [IntPtr]::Zero) { Info "skipped: $file (file manager not found)"; Close-All $fm; return }
  [RoxaWin]::Resize($fmH, 40, 40, $Width, $Height)
  Start-Sleep -Milliseconds 900
  $gui = Start-Process (Join-Path $ExeDir 'RoxaZipG.exe') $guiArgs -PassThru
  $dlg = Wait-Window $gui.Id '#32770' 20
  if ($dlg -eq [IntPtr]::Zero)
  {
    Info "skipped: $file (dialog not found)"
    Close-All $gui; Close-All $fm; return
  }
  [void][RoxaWin]::SetForegroundWindow($dlg)
  Start-Sleep -Seconds 1
  Save-Region $fmH $file
  Close-All $gui
  Start-Sleep -Milliseconds 600
  Close-All $fm
  Start-Sleep -Milliseconds 600
}

Step "Add to archive dialog"
Save-Dialog-Over-Manager '03-add-to-archive.png' `
  ("a -ad -m0=zstd -mx19 `"" + (Join-Path $demo 'release.7z') + "`" `"" + $src + "`"")

Step "Add to archive dialog with encryption"
Save-Dialog-Over-Manager '04-encryption.png' `
  ("a -ad -m0=zstd -mem=AES256 -p`"demo-password`" `"" + (Join-Path $demo 'secret.7z') + "`" `"" + $src + "`"")

Step "Hash dialog (BLAKE3)"
Save-Dialog-Over-Manager '06-hash-blake3.png' `
  ("h -scrcBLAKE3 `"" + (Join-Path $src 'data.bin') + "`"")

Get-Process RoxaZipFM, RoxaZipG -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600
try { Remove-Item $demo -Recurse -Force -ErrorAction Stop }
catch { Info "note: the demo directory is still in use: $demo" }

Step "Result"
Info ("screenshots : {0}" -f $shots.Count)
foreach ($s in $shots)
{
  $img = [System.Drawing.Image]::FromFile((Join-Path $OutDir $s))
  Info ("  {0,-26} {1}x{2}" -f $s, $img.Width, $img.Height)
  $img.Dispose()
}
Info "still manual: 05-context-menu.png (the Windows 11 menu needs a real right-click)"

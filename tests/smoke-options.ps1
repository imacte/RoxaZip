# Run against a built x64 file manager. Changes in options are cancelled.
param([Parameter(Mandatory=$true)][string]$Exe)
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class OptionsSmoke {
  public delegate bool EnumProc(IntPtr hwnd, IntPtr param);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr param);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr param);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
  public static IntPtr Send(IntPtr h, uint msg, int w) { IntPtr result; if(SendMessageTimeout(h,msg,(IntPtr)w,IntPtr.Zero,2,5000,out result)==IntPtr.Zero) throw new Exception("Message timed out"); return result; }
  public static IntPtr Window(int pid, string cls) {
    IntPtr result = IntPtr.Zero;
    EnumWindows((h,p) => { uint id; GetWindowThreadProcessId(h,out id); var s=new StringBuilder(256); GetClassName(h,s,256); if(id==pid && s.ToString()==cls) result=h; return true; },IntPtr.Zero);
    return result;
  }
  public static IntPtr Child(IntPtr root, string cls, int id) {
    IntPtr result=IntPtr.Zero;
    EnumChildWindows(root,(h,p)=> {var s=new StringBuilder(256); GetClassName(h,s,256); if((cls==null || s.ToString()==cls) && (id<0 || GetDlgCtrlID(h)==id)) result=h; return true;},IntPtr.Zero);
    return result;
  }
}
"@
function Start-SmokeProcess([string]$Path, [string]$Arguments = '') {
  $info = [Diagnostics.ProcessStartInfo]::new($Path, $Arguments)
  $info.UseShellExecute = $false
  $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
  return [Diagnostics.Process]::Start($info)
}
Write-Output 'Starting options smoke test'
$p = Start-SmokeProcess $Exe
try {
  Start-Sleep -Seconds 2
  $main = [OptionsSmoke]::Window($p.Id, '7-Zip::FM')
  if ($main -eq [IntPtr]::Zero) { throw 'Main window not found' }
  for ($round = 1; $round -le 3; $round++) {
    [void][OptionsSmoke]::PostMessage($main, 0x111, [IntPtr]900, [IntPtr]::Zero)
    Start-Sleep -Seconds 1
    $dialog = [OptionsSmoke]::Window($p.Id, '#32770')
    if ($dialog -eq [IntPtr]::Zero) { throw 'Options dialog not found' }
    $tab = [OptionsSmoke]::Child($dialog, 'SysTabControl32', -1)
    if ($tab -eq [IntPtr]::Zero) { throw 'Tab control not found' }
    if ([OptionsSmoke]::Send($tab,0x1304,0).ToInt32() -ne 6) { throw 'Expected 6 tabs' }
    for ($i = 0; $i -lt 6; $i++) {
      if ([OptionsSmoke]::Send($dialog,0x465,$i) -eq [IntPtr]::Zero) { throw "Failed to select tab $i" }
      Start-Sleep -Milliseconds 200
      if ([OptionsSmoke]::Send($tab,0x130B,0).ToInt32() -ne $i) { throw "Wrong selected tab $i" }
      Write-Output "Round $round tab $i OK"
      if ($i -eq 1) {
        foreach ($id in @(2306,2307,2308,2309,2307,2306)) {
          $radio = [OptionsSmoke]::Child($dialog, 'Button', $id)
          if ($radio -eq [IntPtr]::Zero) { throw "Radio $id missing" }
          if (-not [OptionsSmoke]::IsWindowEnabled($radio)) { throw "Radio $id disabled (modern support missing)" }
          [void][OptionsSmoke]::Send($radio,0xF5,0)
          if ([OptionsSmoke]::Send($radio,0xF0,0).ToInt32() -ne 1) { throw "Radio $id not selected" }
          $classic = [OptionsSmoke]::Child($dialog, 'Button', 2301)
          if ([OptionsSmoke]::IsWindowVisible($classic) -ne ($id -eq 2306 -or $id -eq 2308)) { throw "Classic visibility incorrect for $id" }
        }
        Write-Output "Round $round all menu modes and checkbox visibility OK"
      }
    }
    [void][OptionsSmoke]::PostMessage($dialog, 0x111, [IntPtr]2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 500
    if ([OptionsSmoke]::Window($p.Id, '#32770') -ne [IntPtr]::Zero) { throw 'Cancel did not close options' }
  }
  Write-Output 'PASS: options reopened 3 times; all tabs and menu modes work; changes cancelled.'
  # Close while the first default-app query can still be running. Each worker
  # must own its data and stop independently of the destroyed page object.
  for ($round = 0; $round -lt 12; $round++) {
    [void][OptionsSmoke]::PostMessage($main, 0x111, [IntPtr]900, [IntPtr]::Zero)
    $dialog = [IntPtr]::Zero
    for ($retry = 0; $retry -lt 100 -and $dialog -eq [IntPtr]::Zero; $retry++) {
      Start-Sleep -Milliseconds 10
      $dialog = [OptionsSmoke]::Window($p.Id, '#32770')
    }
    if ($dialog -eq [IntPtr]::Zero) { throw 'Rapid reopen failed' }
    [void][OptionsSmoke]::Send($dialog,0x465,0)
    [void][OptionsSmoke]::PostMessage($dialog,0x111,[IntPtr]2,[IntPtr]::Zero)
    for ($retry = 0; $retry -lt 100; $retry++) {
      Start-Sleep -Milliseconds 10
      if ([OptionsSmoke]::Window($p.Id, '#32770') -eq [IntPtr]::Zero) { break }
    }
    if ($retry -eq 100 -or $p.HasExited) { throw 'Rapid close stalled or crashed' }
  }
  Start-Sleep -Milliseconds 500
  [void][OptionsSmoke]::Send($main,0,0)
  Write-Output 'PASS: 12 rapid open/close cycles with background default-app queries.'

} finally {
  if (-not $p.HasExited) { [void][OptionsSmoke]::PostMessage($main,0x10,[IntPtr]::Zero,[IntPtr]::Zero); if (-not $p.WaitForExit(3000)) { Stop-Process -Id $p.Id } }
}

# No shell extension DLL is copied here, so even a broken legacy argument
# matcher cannot alter machine-wide shell registration during this regression.
$testDir = Join-Path $env:TEMP ('7zip-options-files-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testDir)
try {
  $testExe = Join-Path $testDir 'RoxaZipFM.exe'
  Copy-Item -LiteralPath $Exe -Destination $testExe
  $codec = Join-Path (Split-Path $Exe -Parent) 'RoxaZip.dll'
  if (Test-Path -LiteralPath $codec) { Copy-Item -LiteralPath $codec -Destination $testDir }
  $emptyZip = [byte[]](0x50,0x4b,5,6) + [byte[]]::new(18)
  foreach($name in @('backup-ShellMenu=unregister.zip','backup-ShellMenu=register.zip','7zipzs-setdefault/sample.zip')) {
    $archive = Join-Path $testDir $name
    [void](New-Item -ItemType Directory -Path (Split-Path $archive -Parent) -Force)
    [IO.File]::WriteAllBytes($archive, $emptyZip)
    $p = Start-SmokeProcess $testExe ('"' + $archive + '"')
    try {
      Start-Sleep -Seconds 2
      $main = [OptionsSmoke]::Window($p.Id, '7-Zip::FM')
      if ($p.HasExited -or $main -eq [IntPtr]::Zero) { throw "Filename incorrectly treated as helper command: $name" }
      Write-Output "PASS filename: $name"
    } finally {
      if (-not $p.HasExited) { [void][OptionsSmoke]::PostMessage($main,0x10,[IntPtr]::Zero,[IntPtr]::Zero); if (-not $p.WaitForExit(3000)) { Stop-Process -Id $p.Id } }
    }
  }
} finally {
  # Only this test's freshly created files; leave an unexpected file untouched.
  foreach($name in @('RoxaZipFM.exe','RoxaZip.dll','backup-ShellMenu=unregister.zip','backup-ShellMenu=register.zip','7zipzs-setdefault/sample.zip')) {
    $file = Join-Path $testDir $name
    for ($retry = 0; $retry -lt 20 -and (Test-Path -LiteralPath $file); $retry++) {
      try { Remove-Item -LiteralPath $file -ErrorAction Stop }
      catch { if ($retry -eq 19) { throw }; Start-Sleep -Milliseconds 100 }
    }
  }
  [IO.Directory]::Delete((Join-Path $testDir '7zipzs-setdefault'))
  [IO.Directory]::Delete($testDir)
}

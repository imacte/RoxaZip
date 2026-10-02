# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: MIT - see DOC/License-MIT.txt
# Validate the real Windows ICO decoder and alpha bitmap loading path.
# Does not install anything or modify file associations.
param([string]$FileManager, [string]$ArchiveLibrary)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$manifest = Get-Content -LiteralPath "$PSScriptRoot/manifest.json" -Raw | ConvertFrom-Json
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
public static class IconResourceCheck {
  [StructLayout(LayoutKind.Sequential)] struct BitmapInfo {
    public int type, width, height, widthBytes;
    public ushort planes, bitsPixel;
    public IntPtr bits;
  }
  [StructLayout(LayoutKind.Sequential)] struct IconInfo {
    public int isIcon, xHotspot, yHotspot;
    public IntPtr mask, color;
  }
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  static extern IntPtr LoadImage(IntPtr module, string name, uint type, int width, int height, uint flags);
  [DllImport("user32.dll")] static extern bool GetIconInfo(IntPtr icon, out IconInfo info);
  [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr icon);
  [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
  [DllImport("gdi32.dll", EntryPoint="GetObjectW")] static extern int GetObject(IntPtr obj, int size, out BitmapInfo info);
  [DllImport("comctl32.dll")] static extern IntPtr ImageList_Create(int width,int height,uint flags,int initial,int grow);
  [DllImport("comctl32.dll")] static extern int ImageList_Add(IntPtr list,IntPtr bitmap,IntPtr mask);
  [DllImport("comctl32.dll")] static extern bool ImageList_Destroy(IntPtr list);
  delegate bool EnumName(IntPtr module,IntPtr type,IntPtr name,IntPtr param);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string file,IntPtr reserved,uint flags);
  [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr module);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool EnumResourceNames(IntPtr module,IntPtr type,EnumName callback,IntPtr param);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int LoadString(IntPtr module,uint id,StringBuilder buffer,int length);
  public static string Mapping(string file, int[] expectedGroups) {
    IntPtr module=LoadLibraryEx(file,IntPtr.Zero,0x22);
    if(module==IntPtr.Zero) throw new Exception("Cannot load resources: "+file);
    try {
      var ids=new List<int>();
      EnumName callback=(m,t,n,p)=>{
        // RC represents ID zero as a named "0" resource on some SDKs.
        if((n.ToInt64() >> 16)==0) ids.Add(n.ToInt32());
        else {
          string name=Marshal.PtrToStringUni(n); int id;
          if(!Int32.TryParse(name.TrimStart('#'),out id)) return false;
          ids.Add(id);
        }
        return true;
      };
      if(!EnumResourceNames(module,new IntPtr(14),callback,IntPtr.Zero)) throw new Exception("Cannot enumerate group icons, Win32 error "+Marshal.GetLastWin32Error()+", groups seen "+ids.Count);
      if(ids.Count!=expectedGroups.Length) throw new Exception("Wrong group icon count: "+file);
      for(int i=0;i<ids.Count;i++) if(ids[i]!=expectedGroups[i]) throw new Exception("Icon index order changed: "+file);
      var buffer=new StringBuilder(8192);
      if(LoadString(module,100,buffer,buffer.Capacity)==0) throw new Exception("Missing extension mapping");
      var indices=new HashSet<int>();
      foreach(string pair in buffer.ToString().Split(' ')) {
        string[] fields=pair.Split(':'); int index;
        if(fields.Length!=2 || !Int32.TryParse(fields[1],out index) || index<0 || index>=ids.Count)
          throw new Exception("Invalid extension mapping: "+pair);
        indices.Add(index);
      }
      if(indices.Count!=34) throw new Exception("Not all 34 formats have distinct mappings");
      return buffer.ToString();
    } finally {FreeLibrary(module);}
  }
  public static void Icon(string path, int size) {
    IntPtr icon=LoadImage(IntPtr.Zero,path,1,size,size,0x10);
    if(icon==IntPtr.Zero) throw new Exception("LoadImage ICON failed: "+path+" @ "+size);
    try {
      IconInfo info;
      if(!GetIconInfo(icon,out info)) throw new Exception("GetIconInfo failed");
      try {
        BitmapInfo bitmap;
        if(GetObject(info.color,Marshal.SizeOf(typeof(BitmapInfo)),out bitmap)==0 || bitmap.width!=size || bitmap.height!=size)
          throw new Exception("Wrong icon dimensions: "+path);
      } finally { DeleteObject(info.color);DeleteObject(info.mask); }
    } finally { DestroyIcon(icon); }
  }
  public static void Bitmap(string path, int width, int height, bool requireAntialiasing) {
    IntPtr bitmap=LoadImage(IntPtr.Zero,path,0,0,0,0x10|0x2000);
    if(bitmap==IntPtr.Zero) throw new Exception("LoadImage BITMAP failed: "+path);
    try {
      BitmapInfo info;
      if(GetObject(bitmap,Marshal.SizeOf(typeof(BitmapInfo)),out info)==0 || info.width!=width || info.height!=height || info.bitsPixel!=32 || info.bits==IntPtr.Zero)
        throw new Exception("Not the expected 32-bit DIB: "+path);
      byte[] pixels=new byte[info.widthBytes*info.height];
      Marshal.Copy(info.bits,pixels,0,pixels.Length);
      bool transparent=false,visible=false,antialiased=false;
      for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
        int p=y*info.widthBytes+x*4, a=pixels[p+3];
        transparent|=a==0;visible|=a>=128;antialiased|=a>0&&a<255;
        if(pixels[p]>a || pixels[p+1]>a || pixels[p+2]>a) throw new Exception("RGB is not premultiplied: "+path);
      }
      if(!transparent || !visible || (requireAntialiasing && !antialiased)) throw new Exception("Missing alpha coverage: "+path);
      if(!requireAntialiasing && antialiased) throw new Exception("Pixel-aligned menu acquired a soft alpha edge: "+path);
      IntPtr list=ImageList_Create(width,height,0x21,0,1);
      if(list==IntPtr.Zero) throw new Exception("ImageList_Create failed");
      try { if(ImageList_Add(list,bitmap,IntPtr.Zero)!=0) throw new Exception("ImageList_Add failed: "+path); }
      finally {ImageList_Destroy(list);}
    } finally {DeleteObject(bitmap);}
  }
}
'@
$icons = @($manifest.formats | ForEach-Object { $_.target }) + @($manifest.applications | ForEach-Object { $_.targets })
$count = 0
foreach ($icon in $icons) {
  $bytes = [IO.File]::ReadAllBytes((Join-Path $root $icon))
  if ([BitConverter]::ToUInt16($bytes,4) -ne $manifest.sizes.Count) { throw "Missing ICO frames: $icon" }
  foreach ($size in $manifest.sizes) {
    [IconResourceCheck]::Icon((Join-Path $root $icon),$size)
    $count++
  }
}
$bmps = @($manifest.toolbars | ForEach-Object { $_.targets })
foreach ($bmp in $bmps) { [IconResourceCheck]::Bitmap((Join-Path $root $bmp.path),$bmp.width,$bmp.height,$true) }
[IconResourceCheck]::Bitmap((Join-Path $root $manifest.menu.target),$manifest.menu.size,$manifest.menu.size,$false)
$mapped = @($icons) + @($bmps | ForEach-Object { $_.path }) + @($manifest.package | ForEach-Object { $_.target }) + @($manifest.menu.target) + @($manifest.excluded)
$tracked = & git -C $root ls-files '*.ico' '*.bmp' '*.png' '*.svg'
foreach ($file in $tracked) {
  if ($file -notlike 'design/icons/*' -and $file -notin $mapped) { throw "Uncovered image resource: $file" }
}
Write-Output "PASS: $count native ICO size loads, 15 alpha BMPs, ImageList insertion and complete tracked-resource coverage."
if ($FileManager) {
  $mapping = [IconResourceCheck]::Mapping((Resolve-Path $FileManager).Path, [int[]](@(1,100) + @(201..234)))
  for ($i=0; $i -lt $manifest.formats.Count; $i++) {
    $ext = $manifest.formats[$i].name
    if ($ext -eq 'split') { $ext='001' }
    if ($ext -eq 'sqfs') { $ext='squashfs' }
    if (($mapping -split ' ') -notcontains ($ext + ':' + ($i+2))) { throw "Wrong bundled mapping: $ext" }
  }
  Write-Output 'PASS: compiled File Manager icon order and all 34 format mappings.'
}
if ($ArchiveLibrary) {
  $mapping = [IconResourceCheck]::Mapping((Resolve-Path $ArchiveLibrary).Path, [int[]](0..33))
  Write-Output 'PASS: compiled archive library icon order and all 34 format mappings.'
}

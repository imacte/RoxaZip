@echo off
REM Build some release of RoxaZip

SET COPYCMD=/Y /B
SET COPTS=-m0=lzma -mx9 -ms=on -mf=bcj2
SET URL=https://www.7-zip.org/a/7z2603.exe
SET VERSION=26.03
SET SZIP="C:\Program Files\7-Zip\7z.exe"
REM LURL must match the layout of the REMOTE repository: this repo keeps the upstream
REM CPP/7zip tree, so the path is the same as upstream - only the repository differs.
REM It stays 404 until the rename is pushed to master, so "curl -f" fails loudly.
SET LURL=https://raw.githubusercontent.com/imacte/RoxaZip/master/CPP/7zip/Bundles

SET WD=%cd%
SET SKEL=%WD%\skel

REM Download our skeleton files
mkdir %WD%\totalcmd
mkdir %SKEL%
cd %SKEL%
curl %URL% -L -o 7-Zip.exe
IF %errorlevel% NEQ 0 EXIT 1
%SZIP% x 7-Zip.exe
IF %errorlevel% NEQ 0 EXIT 1
del 7-Zip.exe
REM The help file comes from the upstream skeleton; ship it under the RoxaZip name
REM (the installer, the uninstaller and the program expect "RoxaZip.chm").
if exist 7-zip.chm ren 7-zip.chm RoxaZip.chm
goto start

@rem Doit function
:doit
SET ARCH=%~1
SET ZIP32=%~2
SET BIN=%~3
SET TCDLL=%~4
echo Doing %ARCH% in SOURCE=%BIN%

REM 7-Zip Files
cd %SKEL%
del *.exe *.dll *.sfx
FOR %%f IN (RoxaZip.dll RoxaZip.exe RoxaZip.sfx RoxaZipA.dll RoxaZipA.exe RoxaZipCon.sfx RoxaZipFM.exe RoxaZipG.exe RoxaZipShell.dll RoxaZipXA.dll Uninstall.exe) DO (
  copy %BIN%\%%f %%f
  IF %errorlevel% NEQ 0 EXIT 1
)
IF NOT "%ZIP32%" == "" (
  copy %ZIP32% RoxaZipShell32.dll
  IF %errorlevel% NEQ 0 EXIT 1
)
%SZIP% a ..\%ARCH%.7z %COPTS%
cd %WD%
copy %BIN%\Install.exe + %ARCH%.7z RoxaZip-%VERSION%-windows-%ARCH%.exe
IF %errorlevel% NEQ 0 EXIT 1
del %ARCH%.7z

REM Codec Files
mkdir codecs-%ARCH%
FOR %%f IN (brotli flzma2 lizard lz4 lz5 zstd) DO (
  copy %BIN%\%%f.dll codecs-%ARCH%\%%f.dll
  IF %errorlevel% NEQ 0 EXIT 1
)
copy %BIN%\RoxaZipA.dll %WD%\totalcmd\%TCDLL%
IF %errorlevel% NEQ 0 EXIT 1
cd codecs-%ARCH%
curl -f %LURL%/Codecs/LICENSE --output LICENSE
IF %errorlevel% NEQ 0 EXIT 1
curl -f %LURL%/Codecs/README.md --output README.md
IF %errorlevel% NEQ 0 EXIT 1
%SZIP% a ..\RoxaZip-%VERSION%-codecs-%ARCH%.7z %COPTS%
IF %errorlevel% NEQ 0 EXIT 1
cd %WD% && rd /S /Q Codecs-%ARCH%
goto :eof
REM end of doit function.

REM Currently we build 3 architectures as 6 targets with and without darkmode (ndm suffix)
:start

call :doit x86       ""                            "%WD%\bin-x86"       "tc7z.dll"
call :doit x86-ndm   ""                            "%WD%\bin-x86-ndm"   "tc7z.dll"

call :doit x64       "%WD%\bin-x86\RoxaZipShell.dll"      "%WD%\bin-x64"       "tc7z64.dll"
call :doit x64-ndm   "%WD%\bin-x86-ndm\RoxaZipShell.dll"  "%WD%\bin-x64-ndm"   "tc7z64.dll"

call :doit arm64     ""                            "%WD%\bin-arm64"     "tc7zArm64.dll"
call :doit arm64-ndm ""                            "%WD%\bin-arm64-ndm" "tc7zArm64.dll"

REM Total Commander DLL
cd %WD%\totalcmd
curl -f %LURL%/TotalCMD/LICENSE --output LICENSE
IF %errorlevel% NEQ 0 EXIT 1
curl -f %LURL%/TotalCMD/README.md --output README.md
IF %errorlevel% NEQ 0 EXIT 1
%SZIP% a ..\RoxaZip-%VERSION%-totalcmd.7z %COPTS%
IF %errorlevel% NEQ 0 EXIT 1

REM Cleanup
cd %WD%
rd /S /Q %SKEL%
rd /S /Q %WD%\totalcmd

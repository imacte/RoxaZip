@echo off
@rem RoxaZip
@rem Copyright (c) 2026 RoxaZip contributors
@rem License: MIT - see DOC/License-MIT.txt
rem Builds Package\Output\probe-modern-menu.exe (needs the Visual Studio C++ tools).
setlocal
set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
  echo ERROR: vcvars64.bat not found, edit this file.
  exit /b 1
)
call "%VCVARS%" >nul 2>&1
cd /d "%~dp0"
if not exist Output mkdir Output
cl /nologo /EHsc /W4 /DUNICODE /D_UNICODE probe-modern-menu.cpp /link shell32.lib ole32.lib user32.lib shlwapi.lib /out:Output\probe-modern-menu.exe

# RoxaZip
# Copyright (c) 2026 RoxaZip contributors
# License: GNU LGPL v2.1-or-later - see COPYING
# Shared by UI/FileManager and Bundles/Fm, after 7zip.mak defines the tool flags.
# Property pages and their stack-allocating caller must agree on class layouts.
FM_PAGE_HEADERS = \
  ../../UI/FileManager/SystemPage.h \
  ../../UI/FileManager/MenuPage.h \
  ../../UI/FileManager/FoldersPage.h \
  ../../UI/FileManager/EditPage.h \
  ../../UI/FileManager/SettingsPage.h \
  ../../UI/FileManager/LangPage.h \
  ../../UI/FileManager/ShellIntegrationModern.h \
  ../../UI/FileManager/ShellMenuTransaction.h \
  ../../UI/FileManager/ShellOperationWait.h \
  ../../UI/FileManager/AssocCommand.h

$O\OptionsDialog.obj $O\SystemPage.obj $O\MenuPage.obj $O\FoldersPage.obj \
$O\EditPage.obj $O\SettingsPage.obj $O\LangPage.obj $O\FM.obj: \
  ../../UI/FileManager/$(*B).cpp $(FM_PAGE_HEADERS)
	$(CC) $(CFLAGS_O1) -Yu"StdAfx.h" -Fp$O/a.pch ../../UI/FileManager/$(*B).cpp

$O\RegistryContextMenu.obj: ../../UI/Explorer/RegistryContextMenu.cpp ../../UI/Explorer/RegistryContextMenu.h
	$(CC) $(CFLAGS_O1) -Yu"StdAfx.h" -Fp$O/a.pch ../../UI/Explorer/RegistryContextMenu.cpp

!IFNDEF UNDER_CE
!IFNDEF Z7_NO_MODERN_SHELL_INTEGRATION
LIBS = $(LIBS) windowsapp.lib

!IFNDEF CPPWINRT_INCLUDE
!IFDEF WINDOWSSDKDIR
!IFDEF WINDOWSSDKVERSION
CPPWINRT_INCLUDE=$(WINDOWSSDKDIR)Include\$(WINDOWSSDKVERSION)cppwinrt
!ENDIF
!ENDIF
!ENDIF
!IFNDEF CPPWINRT_INCLUDE
!IF EXIST(cppwinrt_path.mak)
!INCLUDE cppwinrt_path.mak
!ENDIF
!ENDIF
!IFNDEF CPPWINRT_INCLUDE
!ERROR Initialize the Visual Studio developer command prompt or set CPPWINRT_INCLUDE.
!ENDIF
!IF !EXIST("$(CPPWINRT_INCLUDE)\winrt\base.h")
!ERROR Invalid CPPWINRT_INCLUDE: expected winrt\base.h. Initialize the Windows SDK environment.
!ENDIF

!IF "$(ZIP7_DARKMODE)" == "1"
# Dark mode already selects C++20. Avoid conflicting /std flags under /WX.
FM_WINRT_STANDARD =
!ELSE
# Recent MSVC rejects the experimental coroutine headers used in C++17 mode.
FM_WINRT_STANDARD = -std:c++20
!ENDIF

# WinRT uses its own language standard, so it cannot share the program's PCH.
$O\ShellIntegrationModern.obj: ../../UI/FileManager/ShellIntegrationModern.cpp ../../UI/FileManager/ShellIntegrationModern.h ../../UI/FileManager/ShellOperationWait.h
	$(CC) $(CFLAGS_O1) -DZ7_ENABLE_MODERN_SHELL_INTEGRATION $(FM_WINRT_STANDARD) -W3 -EHsc -I"$(CPPWINRT_INCLUDE)" ../../UI/FileManager/ShellIntegrationModern.cpp
!ENDIF
!ENDIF

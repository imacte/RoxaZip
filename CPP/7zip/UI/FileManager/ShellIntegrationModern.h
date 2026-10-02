/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: GNU LGPL v2.1-or-later - see COPYING
 */
// ShellIntegrationModern.h
//
// The Windows 11 (compact) context menu shows the commands of this fork only if
// the sparse package (see the Package\ directory) is registered for the current
// user. That registration is per user and needs no administrator rights, so it
// can be toggled from the options page ("RoxaZip" page).
//
// The shell lists the commands of a package in the classic menu for files, but
// not for directories, so a per-user classic registration for Folder/Directory
// (HKCU\Software\Classes) belongs to this mode as well - also without a UAC
// prompt, unlike the machine-wide registration that the checkboxes above use.
//
// This header intentionally contains no WinRT types: the implementation is the
// only translation unit that includes C++/WinRT.

#ifndef ZIP7_INC_SHELL_INTEGRATION_MODERN_H
#define ZIP7_INC_SHELL_INTEGRATION_MODERN_H

#include "../../../Common/MyWindows.h"
#include "../../../Common/MyString.h"

namespace NShellIntegrationModern {

  // <program dir>\RoxaZip.ShellExtension_x64.msix  (empty if it does not exist)
  UString Get_DefaultMsixPath();

  // is one of the packages of this fork registered for the current user?
  bool Is_Installed(UString *packageFullName = NULL);
  bool Is_Supported();

  // register / unregister the sparse package for the current user
  // (sparse package: the payload stays in the program directory)
  HRESULT Install(const UString &msixPath, const UString &externalDir, UString &errorText);
  HRESULT Remove(UString &errorText);

  // classic registration for Folder/Directory in HKCU\Software\Classes
  // (needed for folders in the classic menu when the package is used)
  bool Is_FolderRegistration_PerUser();
  unsigned Get_FolderRegistration_Mask();
  HRESULT Set_FolderRegistration_Mask(unsigned mask, UString &errorText);
  HRESULT Set_FolderRegistration_PerUser(bool enable, UString &errorText);

  // the CLSID of the shell extension of this fork
  const wchar_t *Get_Clsid();

  // ------------------------------------------------------- elevation helper --
  // true if this process already runs with administrator rights
  bool Is_Process_Elevated();

  /* Runs "RoxaZipFM.exe <args>" elevated (one UAC prompt) and waits for it. Used for
     every change that writes to HKEY_LOCAL_MACHINE / HKEY_CLASSES_ROOT, so the
     program never has to be restarted as administrator. errorText gets a message
     when the user cancels the prompt or the helper fails. */
  HRESULT Run_Elevated_Self(const UString &args, UString &errorText, HWND owner = NULL);

  // convenience wrapper: "-ShellMenu=register" / "-ShellMenu=unregister"
  HRESULT Run_Elevated_ShellRegistration(bool enable, UString &errorText);
}

#endif

/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: GNU LGPL v2.1-or-later - see COPYING
 */
// StoreUpdate.h
//
// In-app updates for the Microsoft Store variant (see RoxaZipPackage\). The
// Windows.Services.Store API can only be used by a process that runs with the
// package identity of the Store package, so the classic installation is sent to
// the download page instead of being updated in place.
//
// This header intentionally contains no WinRT types: StoreUpdate.cpp is the only
// translation unit that includes C++/WinRT (the same split as
// ShellIntegrationModern.h, which keeps the C++/WinRT compiler flags off the
// rest of the program).

#ifndef ZIP7_INC_STORE_UPDATE_H
#define ZIP7_INC_STORE_UPDATE_H

#include "../../../Common/MyWindows.h"
#include "../../../Common/MyString.h"

namespace NStoreUpdate {

  /* True when this process runs with the package identity of the Store package.
     Without one the Store APIs are not available at all. */
  bool Is_Supported();

  // version of the running package, empty when there is no package identity
  UString Get_Installed_Version();

  struct CResult
  {
    bool HasUpdate;     // the Store offers a newer version of this app
    bool Installed;     // the offered version was downloaded and installed
    UString Version;    // version the Store offers, empty when there is none
    UString Error;      // failure text of the Store / WinRT, empty on success
    unsigned State;     // StorePackageUpdateState when the install did not finish

    CResult(): HasUpdate(false), Installed(false), State(0) {}
    void Clear()
    {
      HasUpdate = false;
      Installed = false;
      State = 0;
      Version.Empty();
      Error.Empty();
    }
  };

  /* Asks the Store for updates of this app. The WinRT operation runs on a worker
     thread while the caller's messages keep being pumped, so call it from the UI
     thread; it returns when the Store answered. */
  HRESULT Get_Available_Updates(CResult &result);

  /* Downloads and installs what Get_Available_Updates() found. The Store shows
     its own consent and progress dialogs; the caller's window is only pumped. */
  HRESULT Download_And_Install(CResult &result);

  /* Starts RoxaZip again. The Store variant is started through its app user
     model id, because the folder of the previous package version is gone after
     an update; the classic installation is started from its program path. */
  bool Restart();

  // page the classic installation is sent to
  extern const wchar_t *k_DownloadPage;
}

#endif

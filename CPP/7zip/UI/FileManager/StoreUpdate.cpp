/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: GNU LGPL v2.1-or-later - see COPYING
 */
// StoreUpdate.cpp
//
// In-app updates through the Microsoft Store. See StoreUpdate.h and
// DOC/StoreSubmission.md.
//
// The WinRT calls block until the Store answers, so they run on a short-lived
// MTA thread while the caller's messages keep being pumped
// (WaitForShellOperation) - a single-threaded apartment must not block inside
// IAsyncOperation::get(), which is the same reason the shell integration has its
// own worker thread.

#include "StdAfx.h"

#include "StoreUpdate.h"
#include "ShellIntegrationModern.h"
#include "ShellOperationWait.h"

#include <shellapi.h>

#ifdef Z7_ENABLE_STORE_UPDATE

// C++/WinRT (the projections ship with the Windows SDK, no NuGet package
// needed); the build rule selects C++20 for this file.
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Services.Store.h>

// the WinRT API umbrella (RoGetActivationFactory, ...); the pragma makes this
// independent of the link order of the makefile.
#pragma comment(lib, "windowsapp.lib")

#endif

namespace NStoreUpdate {

const wchar_t *k_DownloadPage = L"https://github.com/imacte/RoxaZip/releases/latest";

// Application/@Id of the file manager in Package.appxmanifest; the program is
// activated through "<package family name>!<this id>".
static const wchar_t *k_ApplicationId = L"RoxaZip.FileManager";

#ifdef Z7_ENABLE_STORE_UPDATE

static UString HString_To_UString(const winrt::hstring &s)
{
  return UString(s.c_str());
}

static UInt64 Version_To_UInt64(const winrt::Windows::ApplicationModel::PackageVersion &v)
{
  return ((UInt64)v.Major << 48) | ((UInt64)v.Minor << 32)
       | ((UInt64)v.Build << 16) | (UInt64)v.Revision;
}

static UString Version_To_UString(const winrt::Windows::ApplicationModel::PackageVersion &v)
{
  UString s;
  s.Add_UInt32(v.Major);
  s.Add_Dot();
  s.Add_UInt32(v.Minor);
  s.Add_Dot();
  s.Add_UInt32(v.Build);
  s.Add_Dot();
  s.Add_UInt32(v.Revision);
  return s;
}

struct CThreadOp
{
  enum enum_Type { kQuery, kInstall };
  enum_Type Type;
  bool HasUpdate;
  bool Installed;
  unsigned State;
  UString Version;
  UString Error;
  HRESULT Hr;
  CThreadOp(): Type(kQuery), HasUpdate(false), Installed(false), State(0), Hr(E_FAIL) {}
};

static DWORD WINAPI Op_Thread(LPVOID param)
{
  CThreadOp &op = *(CThreadOp *)param;
  try
  {
    // the worker thread starts in the MTA, where .get() is allowed
    winrt::init_apartment(winrt::apartment_type::multi_threaded);

    const winrt::Windows::Services::Store::StoreContext context =
        winrt::Windows::Services::Store::StoreContext::GetDefault();
    const winrt::Windows::Foundation::Collections::IVectorView<
        winrt::Windows::Services::Store::StorePackageUpdate> updates =
        context.GetAppAndOptionalStorePackageUpdatesAsync().get();

    if (updates.Size() != 0)
    {
      op.HasUpdate = true;

      // the newest version among the packages the Store offers
      winrt::Windows::ApplicationModel::PackageVersion best =
          updates.GetAt(0).Package().Id().Version();
      for (unsigned i = 1; i < updates.Size(); i++)
      {
        const winrt::Windows::ApplicationModel::PackageVersion v =
            updates.GetAt(i).Package().Id().Version();
        if (Version_To_UInt64(best) < Version_To_UInt64(v))
          best = v;
      }
      op.Version = Version_To_UString(best);

      if (op.Type == CThreadOp::kInstall)
      {
        /* The Store shows the consent and progress UI for this call; it returns
           when the packages were downloaded and installed. */
        const winrt::Windows::Services::Store::StorePackageUpdateResult result =
            context.RequestDownloadAndInstallStorePackageUpdatesAsync(updates).get();
        op.State = (unsigned)result.OverallState();
        if (result.OverallState()
            == winrt::Windows::Services::Store::StorePackageUpdateState::Completed)
          op.Installed = true;
      }
    }

    op.Hr = S_OK;
  }
  catch (const winrt::hresult_error &e)
  {
    op.Hr = e.code();
    op.Error = HString_To_UString(e.message());
  }
  catch (...)
  {
    op.Hr = E_FAIL;
    op.Error = L"unknown error";
  }
  return 0;
}

static HRESULT Run_Op(CThreadOp &op)
{
  DWORD threadId = 0;
  HANDLE h = ::CreateThread(NULL, 0, Op_Thread, &op, 0, &threadId);
  if (!h)
    return HRESULT_FROM_WIN32(::GetLastError());
  // Keep the stack-owned operation alive even if message waiting fails.
  if (WaitForShellOperation(h) != WAIT_OBJECT_0)
    ::WaitForSingleObject(h, INFINITE);
  ::CloseHandle(h);
  return op.Hr;
}

#endif  // Z7_ENABLE_STORE_UPDATE

bool Is_Supported()
{
#ifdef Z7_ENABLE_STORE_UPDATE
  return NShellIntegrationModern::Is_Running_Packaged();
#else
  return false;
#endif
}

UString Get_Installed_Version()
{
#ifdef Z7_ENABLE_STORE_UPDATE
  if (!NShellIntegrationModern::Is_Running_Packaged())
    return UString();
  try
  {
    winrt::init_apartment(winrt::apartment_type::single_threaded);
    return Version_To_UString(
        winrt::Windows::ApplicationModel::Package::Current().Id().Version());
  }
  catch (...) { }
#endif
  return UString();
}

HRESULT Get_Available_Updates(CResult &result)
{
  result.Clear();
#ifdef Z7_ENABLE_STORE_UPDATE
  if (!Is_Supported())
    return E_NOTIMPL;
  CThreadOp op;
  op.Type = CThreadOp::kQuery;
  const HRESULT hr = Run_Op(op);
  result.HasUpdate = op.HasUpdate;
  result.Version = op.Version;
  result.Error = op.Error;
  result.State = op.State;
  return hr;
#else
  return E_NOTIMPL;
#endif
}

HRESULT Download_And_Install(CResult &result)
{
  result.Clear();
#ifdef Z7_ENABLE_STORE_UPDATE
  if (!Is_Supported())
    return E_NOTIMPL;
  /* The Store is asked again instead of keeping the update list of a previous
     call: the WinRT collection belongs to the apartment that created it, and the
     Store may have started the download in the meantime. */
  CThreadOp op;
  op.Type = CThreadOp::kInstall;
  const HRESULT hr = Run_Op(op);
  result.HasUpdate = op.HasUpdate;
  result.Installed = op.Installed;
  result.Version = op.Version;
  result.Error = op.Error;
  result.State = op.State;
  return hr;
#else
  return E_NOTIMPL;
#endif
}

bool Restart()
{
#ifdef Z7_ENABLE_STORE_UPDATE
  if (NShellIntegrationModern::Is_Running_Packaged())
  {
    try
    {
      winrt::init_apartment(winrt::apartment_type::single_threaded);
      const UString family = HString_To_UString(
          winrt::Windows::ApplicationModel::Package::Current().Id().FamilyName());
      if (!family.IsEmpty())
      {
        /* The program folder of the version that was running is removed by the
           update, so the old path cannot be used again; the package is started
           through its app user model id instead. */
        UString target;
        target += L"shell:AppsFolder\\";
        target += family;
        target += L"!";
        target += k_ApplicationId;
        const HINSTANCE res = ::ShellExecuteW(NULL, L"open", L"explorer.exe",
            target.Ptr(), NULL, SW_SHOWNORMAL);
        if ((INT_PTR)res > 32)
          return true;
      }
    }
    catch (...) { }
  }
#endif

  // the classic installation (or a packaged start that failed): the program
  // path is still valid
  wchar_t path[MAX_PATH];
  const DWORD len = ::GetModuleFileNameW(NULL, path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH)
    return false;
  const HINSTANCE res = ::ShellExecuteW(NULL, L"open", path, NULL, NULL, SW_SHOWNORMAL);
  return (INT_PTR)res > 32;
}

}

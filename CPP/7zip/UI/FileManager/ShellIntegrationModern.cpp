/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: GNU LGPL v2.1-or-later - see COPYING
 */
// ShellIntegrationModern.cpp

#include "StdAfx.h"

#include "ShellIntegrationModern.h"
#include "ShellOperationWait.h"

#include "../../../Windows/DLL.h"
#include "../../../Windows/ErrorMsg.h"
#include "../../../Windows/FileFind.h"

#include <shellapi.h>

#ifdef Z7_ENABLE_MODERN_SHELL_INTEGRATION

// C++/WinRT (the projections ship with the Windows SDK, no NuGet package needed).
// C++20 selects standard coroutines instead of MSVC's retired experimental ones.
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Management.Deployment.h>

// the WinRT API umbrella (RoGetActivationFactory, RoOriginateLanguageException,
// ...). The pragma makes this independent of the link order of the makefile.
#pragma comment(lib, "windowsapp.lib")

#endif

using namespace NWindows;

namespace NShellIntegrationModern {

// {23170F69-20BB-278A-1000-000100020000} - must match the com:Class in
// Package/AppxManifest.xml and the registration of the Explorer DLL.
static const wchar_t *k_Clsid = L"{3878DDB7-37F6-4265-BB4F-835DC2A790ED}";
static const wchar_t *k_PackageName = L"RoxaZip.ShellExtension";
static const wchar_t *k_MsixFileName = L"RoxaZip.ShellExtension_x64.msix";
static const wchar_t *k_RegistryKeyName = L"RoxaZip";

const wchar_t *Get_Clsid() { return k_Clsid; }


UString Get_DefaultMsixPath()
{
  const FString dir = NDLL::GetModuleDirPrefix();
  {
    FString path = dir;
    path += k_MsixFileName;
    if (NWindows::NFile::NFind::DoesFileExist_Raw(path))
      return fs2us(path);
  }

  /* build-shell-package.ps1 names the package with its version:
       RoxaZip.ShellExtension_<version>_x64.msix
     so the program directory is searched for such a file as well. */
  {
    NWindows::NFile::NFind::CEnumerator enumerator;
    enumerator.SetDirPrefix(dir);
    NWindows::NFile::NFind::CFileInfo fi;
    const UString prefix = L"RoxaZip.ShellExtension";
    const UString suffix = L".msix";
    for (;;)
    {
      if (!enumerator.Next(fi))
        break;
      const UString name = fs2us(fi.Name);
      if (name.Len() <= prefix.Len() + suffix.Len())
        continue;
      if (!name.IsPrefixedBy_NoCase(prefix))
        continue;
      if (!name.Mid(name.Len() - suffix.Len(), suffix.Len()).IsPrefixedBy_NoCase(suffix))
        continue;
      FString path = dir;
      path += fi.Name;
      return fs2us(path);
    }
  }

  return UString();
}


#ifdef Z7_ENABLE_MODERN_SHELL_INTEGRATION

bool Is_Supported()
{
  return true;
}

static UString HString_To_UString(const winrt::hstring &s)
{
  return UString(s.c_str());
}

/*
  IAsyncOperation::get() must not be called on a single-threaded apartment
  thread (the options page runs in one): the completion would have to be
  marshalled back into a thread that is blocked in get(). Install/remove
  therefore run on a short-lived MTA thread.
*/
struct CThreadOp
{
  enum enum_Type { kInstall, kRemove };
  enum_Type Type;
  UString MsixPath;
  UString ExternalDir;
  UString FullName;      // for kRemove: filled by the caller, see below
  UString Error;
  HRESULT Hr;
  CThreadOp(): Type(kInstall), Hr(E_FAIL) {}
};

// "D:\dir\file name.msix" -> "file:///D:/dir/file%20name.msix"
static UString Path_To_FileUri(const UString &path)
{
  UString s = L"file:///";
  const wchar_t *p = path;
  if (path.Len() >= 4 && path[0] == L'\\' && path[1] == L'\\' && path[2] == L'?')
    p = path.Ptr(4);           // skip the \\?\ prefix of long paths
  for (; *p; p++)
  {
    const wchar_t c = *p;
    if (c == L'\\')
      s += L'/';
    else if (c == L' ')
      s += L"%20";
    else
      s += c;
  }
  return s;
}

static DWORD WINAPI Op_Thread(LPVOID param)
{
  CThreadOp &op = *(CThreadOp *)param;
  try
  {
    // the worker thread starts in the MTA, where .get() is allowed
    winrt::init_apartment(winrt::apartment_type::multi_threaded);

    winrt::Windows::Management::Deployment::PackageManager pm;

    if (op.Type == CThreadOp::kInstall)
    {
      winrt::Windows::Management::Deployment::AddPackageOptions options;
      options.ExternalLocationUri(winrt::Windows::Foundation::Uri(Path_To_FileUri(op.ExternalDir).Ptr()));
      winrt::Windows::Management::Deployment::DeploymentResult result =
          pm.AddPackageByUriAsync(
              winrt::Windows::Foundation::Uri(Path_To_FileUri(op.MsixPath).Ptr()),
              options).get();
      if (result.ExtendedErrorCode())
      {
        op.Hr = result.ExtendedErrorCode();
        op.Error = HString_To_UString(result.ErrorText());
      }
      else
        op.Hr = S_OK;
    }
    else
    {
      /* op.FullName was resolved by Remove() on the caller's thread: calling
         Is_Installed() here would ask for a single-threaded apartment on a
         multi-threaded one (RPC_E_CHANGED_MODE). */
      if (op.FullName.IsEmpty())
      {
        op.Hr = S_OK;   // nothing to do
      }
      else
      {
        winrt::Windows::Management::Deployment::DeploymentResult result =
            pm.RemovePackageAsync(op.FullName.Ptr(),
                winrt::Windows::Management::Deployment::RemovalOptions::None).get();
        if (result.ExtendedErrorCode())
        {
          op.Hr = result.ExtendedErrorCode();
          op.Error = HString_To_UString(result.ErrorText());
        }
        else
          op.Hr = S_OK;
      }
    }
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

bool Is_Installed(UString *packageFullName)
{
  try
  {
    winrt::init_apartment(winrt::apartment_type::single_threaded);
    winrt::Windows::Management::Deployment::PackageManager pm;
    // an empty user security id means "the current user"
    for (const winrt::Windows::ApplicationModel::Package &p : pm.FindPackagesForUser(winrt::hstring()))
    {
      if (HString_To_UString(p.Id().Name()) == UString(k_PackageName))
      {
        if (packageFullName)
          *packageFullName = HString_To_UString(p.Id().FullName());
        return true;
      }
    }
  }
  catch (...) { }
  return false;
}

HRESULT Install(const UString &msixPath, const UString &externalDir, UString &errorText)
{
  CThreadOp op;
  op.Type = CThreadOp::kInstall;
  op.MsixPath = msixPath;
  op.ExternalDir = externalDir;
  const HRESULT hr = Run_Op(op);
  errorText = op.Error;
  return hr;
}

HRESULT Remove(UString &errorText)
{
  errorText.Empty();

  // resolved here (single-threaded apartment of the caller), see CThreadOp
  UString fullName;
  if (!Is_Installed(&fullName))
    return S_OK;   // nothing to remove

  CThreadOp op;
  op.Type = CThreadOp::kRemove;
  op.FullName = fullName;
  const HRESULT hr = Run_Op(op);
  errorText = op.Error;
  return hr;
}

#else   // Z7_ENABLE_MODERN_SHELL_INTEGRATION

bool Is_Supported() { return false; }

bool Is_Installed(UString *packageFullName)
{
  if (packageFullName)
    packageFullName->Empty();
  return false;
}

HRESULT Install(const UString &, const UString &, UString &errorText)
{
  errorText = L"not supported in this build";
  return E_NOTIMPL;
}

HRESULT Remove(UString &errorText)
{
  errorText = L"not supported in this build";
  return E_NOTIMPL;
}

#endif  // Z7_ENABLE_MODERN_SHELL_INTEGRATION


// ------------------------------------------------- HKCU\Software\Classes keys --
// These need no administrator rights (the shell merges HKCU\Software\Classes
// into HKEY_CLASSES_ROOT), unlike the machine-wide registration.

bool Is_FolderRegistration_PerUser()
{
  return Get_FolderRegistration_Mask() == 3;
}

unsigned Get_FolderRegistration_Mask()
{
  unsigned mask = 0;
  static const wchar_t *roots[] = { L"Folder", L"Directory" };
  for (unsigned i = 0; i < Z7_ARRAY_SIZE(roots); i++)
  {
    UString key = L"Software\\Classes\\";
    key += roots[i];
    key += L"\\shellex\\ContextMenuHandlers\\";
    key += k_RegistryKeyName;
    HKEY hKey = NULL;
    const LONG res = ::RegOpenKeyExW(HKEY_CURRENT_USER, key.Ptr(), 0, KEY_READ, &hKey);
    if (res == ERROR_SUCCESS)
    {
      mask |= 1u << i;
      ::RegCloseKey(hKey);
    }
  }
  return mask;
}

HRESULT Set_FolderRegistration_PerUser(bool enable, UString &errorText)
{
  return Set_FolderRegistration_Mask(enable ? 3 : 0, errorText);
}

HRESULT Set_FolderRegistration_Mask(unsigned mask, UString &errorText)
{
  static const wchar_t *roots[] = { L"Folder", L"Directory" };
  errorText.Empty();
  for (unsigned i = 0; i < Z7_ARRAY_SIZE(roots); i++)
  {
    UString key = L"Software\\Classes\\";
    key += roots[i];
    key += L"\\shellex\\ContextMenuHandlers\\";
    key += k_RegistryKeyName;

    LONG res;
    if ((mask & (1u << i)) != 0)
    {
      HKEY hKey = NULL;
      DWORD disposition = 0;
      res = ::RegCreateKeyExW(HKEY_CURRENT_USER, key.Ptr(), 0, NULL,
          REG_OPTION_NON_VOLATILE, KEY_WRITE, NULL, &hKey, &disposition);
      if (res == ERROR_SUCCESS)
      {
        const DWORD size = (DWORD)((wcslen(k_Clsid) + 1) * sizeof(wchar_t));
        res = ::RegSetValueExW(hKey, NULL, 0, REG_SZ, (const BYTE *)k_Clsid, size);
        ::RegCloseKey(hKey);
      }
    }
    else
    {
      res = ::RegDeleteKeyW(HKEY_CURRENT_USER, key.Ptr());
      if (res == ERROR_FILE_NOT_FOUND)
        res = ERROR_SUCCESS;
    }

    if (res != ERROR_SUCCESS)
    {
      errorText = NError::MyFormatMessage(res);
      return HRESULT_FROM_WIN32(res);
    }
  }
  return S_OK;
}


// ------------------------------------------------------- elevation helper ----

bool Is_Process_Elevated()
{
  HANDLE token = NULL;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &token))
    return false;
  TOKEN_ELEVATION info;
  info.TokenIsElevated = 0;
  DWORD size = 0;
  const BOOL ok = ::GetTokenInformation(token, TokenElevation, &info, sizeof(info), &size);
  ::CloseHandle(token);
  return ok && info.TokenIsElevated != 0;
}


HRESULT Run_Elevated_Self(const UString &args, UString &errorText, HWND owner)
{
  errorText.Empty();

  const FString dir = NDLL::GetModuleDirPrefix();
  FString exe = dir;
  exe += L"RoxaZipFM.exe";
  if (!NWindows::NFile::NFind::DoesFileExist_Raw(exe))
  {
    errorText = L"RoxaZipFM.exe was not found next to the program";
    return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  }

  SHELLEXECUTEINFOW sei;
  ZeroMemory(&sei, sizeof(sei));
  sei.cbSize = sizeof(sei);
  sei.hwnd = owner;
  sei.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_NOASYNC;
  sei.lpVerb = L"runas";                      // one UAC prompt
  sei.lpFile = exe.Ptr();
  sei.lpParameters = args.Ptr();
  sei.nShow = SW_HIDE;                        // the helper does not open a window

  if (!::ShellExecuteExW(&sei))
  {
    const DWORD err = ::GetLastError();
    if (err == ERROR_CANCELLED)
      errorText = L"the UAC prompt was cancelled";
    else
      errorText = NError::MyFormatMessage(err);
    return HRESULT_FROM_WIN32(err);
  }

  if (sei.hProcess)
  {
    // Do not start a rollback while the elevated helper can still be writing.
    const DWORD waitResult = WaitForShellOperation(sei.hProcess);
    if (waitResult != WAIT_OBJECT_0)
    {
      const DWORD err = ::GetLastError();
      ::CloseHandle(sei.hProcess);
      errorText = NError::MyFormatMessage(err);
      return HRESULT_FROM_WIN32(err);
    }
    DWORD code = 1;
    ::GetExitCodeProcess(sei.hProcess, &code);
    ::CloseHandle(sei.hProcess);
    if (code != 0)
    {
      errorText = L"the elevated operation failed";
      return E_FAIL;
    }
  }
  return S_OK;
}


HRESULT Run_Elevated_ShellRegistration(bool enable, UString &errorText)
{
  return Run_Elevated_Self(enable ? UString(L"-ShellMenu=register") : UString(L"-ShellMenu=unregister"), errorText);
}

}

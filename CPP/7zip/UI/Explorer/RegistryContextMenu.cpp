// RegistryContextMenu.cpp

#include "StdAfx.h"

#include "../../../Common/StringConvert.h"

#include "../../../Windows/DLL.h"
#include "../../../Windows/FileFind.h"
#include "../../../Windows/Registry.h"

#include "RegistryContextMenu.h"

using namespace NWindows;
using namespace NRegistry;

#ifndef UNDER_CE

// does extension can work, if Approved is removed ?
// CLISID (and Approved ?) items are separated for 32-bit and 64-bit code.
// shellex items shared by 32-bit and 64-bit code?

// **** RoxaZip Modification Start ****
// upstream: "{23170F69-40C1-278A-1000-000100020000}"
#define k_Clsid_A "{3878DDB7-37F6-4265-BB4F-835DC2A790ED}"
// **** RoxaZip Modification End ****

static LPCTSTR const k_Clsid = TEXT(k_Clsid_A);
static LPCTSTR const k_ShellExtName = TEXT("RoxaZip Shell Extension");

static LPCTSTR const k_Approved = TEXT("Software\\Microsoft\\Windows\\CurrentVersion\\Shell Extensions\\Approved");
static LPCTSTR const k_Inproc = TEXT("InprocServer32");

// **** RoxaZip Modification Start ****
static LPCSTR const k_KeyPostfix_ContextMenu = "\\shellex\\ContextMenuHandlers\\RoxaZip";
// **** RoxaZip Modification End ****
static LPCSTR const k_KeyPostfix_DragDrop    = "\\shellex\\DragDropHandlers\\RoxaZip";

static LPCSTR const k_KeyName_File      = "*";
static LPCSTR const k_KeyName_Folder    = "Folder";
static LPCSTR const k_KeyName_Directory = "Directory";
static LPCSTR const k_KeyName_Drive     = "Drive";

static LPCSTR const k_shellex_Prefixes[] =
{
  k_KeyName_File,
  k_KeyName_Folder,
  k_KeyName_Directory,
  k_KeyName_Drive
};

static const bool k_shellex_Statuses[2][4] =
{
  { true, true, true, false },
  { false, false, true, true }
};


// RegDeleteKeyExW is supported starting from win2003sp1/xp-pro-x64
// Z7_WIN32_WINNT_MIN < 0x0600  // Vista
#if !defined(Z7_WIN32_WINNT_MIN) \
    || Z7_WIN32_WINNT_MIN  < 0x0502  /* < win2003 */ \
    || Z7_WIN32_WINNT_MIN == 0x0502 && !defined(_M_AMD64)
#define Z7_USE_DYN_RegDeleteKeyExW
#endif

#ifdef Z7_USE_DYN_RegDeleteKeyExW
Z7_DIAGNOSTIC_IGNORE_CAST_FUNCTION
typedef
// WINADVAPI
LONG (APIENTRY *Func_RegDeleteKeyExW)(HKEY hKey, LPCWSTR lpSubKey, REGSAM samDesired, DWORD Reserved);
static Func_RegDeleteKeyExW func_RegDeleteKeyExW;

static void Init_RegDeleteKeyExW()
{
  if (!func_RegDeleteKeyExW)
    func_RegDeleteKeyExW = Z7_GET_PROC_ADDRESS(
    Func_RegDeleteKeyExW, GetModuleHandleW(L"advapi32.dll"),
        "RegDeleteKeyExW");
}
#define INIT_REG_WOW if (wow != 0) Init_RegDeleteKeyExW();
#else
#define INIT_REG_WOW
#endif


static LONG MyRegistry_DeleteKey(HKEY parentKey, LPCTSTR name, UInt32 wow)
{
  if (wow == 0)
    return RegDeleteKey(parentKey, name);

#ifdef Z7_USE_DYN_RegDeleteKeyExW
  if (!func_RegDeleteKeyExW)
    return E_NOTIMPL;
  return func_RegDeleteKeyExW
#else
  return RegDeleteKeyExW
#endif
      (parentKey, GetUnicodeString(name), wow, 0);
}

static LONG MyRegistry_DeleteKey_HKCR(LPCTSTR name, UInt32 wow)
{
  return MyRegistry_DeleteKey(HKEY_CLASSES_ROOT, name, wow);
}

// static NSynchronization::CCriticalSection g_CS;

static AString Get_ContextMenuHandler_KeyName(LPCSTR keyName)
  { return (AString)keyName + k_KeyPostfix_ContextMenu; }

/*
static CSysString Get_DragDropHandler_KeyName(LPCTSTR keyName)
  { return (AString)keyName + k_KeyPostfix_DragDrop); }
*/

static bool CheckHandlerCommon(const AString &keyName, UInt32 wow)
{
  CKey key;
  if (key.Open(HKEY_CLASSES_ROOT, (CSysString)keyName, KEY_READ | wow) != ERROR_SUCCESS)
    return false;
  CSysString value;
  if (key.QueryValue(NULL, value) != ERROR_SUCCESS)
    return false;
  return StringsAreEqualNoCase_Ascii(value, k_Clsid_A);
}

bool CheckContextMenuHandler_Dll(const UString &path, UInt32 wow)
{
  // NSynchronization::CCriticalSectionLock lock(g_CS);

  CSysString s ("CLSID\\");
  s += k_Clsid_A;
  s += "\\InprocServer32";
  
  {
    NRegistry::CKey key;
    if (key.Open(HKEY_CLASSES_ROOT, s, KEY_READ | wow) != ERROR_SUCCESS)
      return false;
    UString regPath;
    if (key.QueryValue(NULL, regPath) != ERROR_SUCCESS)
      return false;
    if (!path.IsEqualTo_NoCase(regPath))
      return false;
  }
  
  return true;
}

bool CheckContextMenuHandler(const UString &path, UInt32 wow)
{
  return CheckContextMenuHandler_Dll(path, wow)
      && CheckHandlerCommon(Get_ContextMenuHandler_KeyName(k_KeyName_File), wow);
}

bool CheckContextMenuHandler_Complete(const UString &path, UInt32 wow)
{
  if (!CheckContextMenuHandler_Dll(path, wow)) return false;
  CKey key;
  CSysString value;
  if (key.Open(HKEY_LOCAL_MACHINE, k_Approved, KEY_READ | wow) != ERROR_SUCCESS
      || key.QueryValue(k_Clsid, value) != ERROR_SUCCESS || value != k_ShellExtName)
    return false;
  CSysString inproc("CLSID\\");
  inproc += k_Clsid_A;
  inproc += "\\InprocServer32";
  if (key.Open(HKEY_CLASSES_ROOT, inproc, KEY_READ | wow) != ERROR_SUCCESS
      || key.QueryValue(TEXT("ThreadingModel"), value) != ERROR_SUCCESS
      || value != TEXT("Apartment")) return false;
  for (unsigned i = 0; i < 2; i++)
    for (unsigned k = 0; k < Z7_ARRAY_SIZE(k_shellex_Prefixes); k++)
      if (k_shellex_Statuses[i][k] && !CheckHandlerCommon(
          AString(k_shellex_Prefixes[k]) +
          (i == 0 ? k_KeyPostfix_ContextMenu : k_KeyPostfix_DragDrop), wow))
        return false;
  return true;
}


static LONG MyCreateKey(CKey &key, HKEY parentKey, LPCTSTR keyName, UInt32 wow)
{
  return key.Create(parentKey, keyName, REG_NONE,
      REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS | wow);
}

LONG SetContextMenuHandler(bool setMode, const UString &path, UInt32 wow)
{
  // NSynchronization::CCriticalSectionLock lock(g_CS);

  INIT_REG_WOW

  LONG res;

  {
  CSysString s ("CLSID\\");
  s += k_Clsid_A;

  if (setMode)
  {
    {
      CKey key;
      res = MyCreateKey(key, HKEY_CLASSES_ROOT, s, wow);
      if (res == ERROR_SUCCESS)
      {
        res = key.SetValue(NULL, k_ShellExtName);
        if (res != ERROR_SUCCESS) return res;
        CKey keyInproc;
        res = MyCreateKey(keyInproc, key, k_Inproc, wow);
        if (res == ERROR_SUCCESS)
        {
          res = keyInproc.SetValue(NULL, path);
          if (res != ERROR_SUCCESS) return res;
          res = keyInproc.SetValue(TEXT("ThreadingModel"), TEXT("Apartment"));
        }
      }
    }
    
    if (res != ERROR_SUCCESS) return res;
    {
      CKey key;
      res = MyCreateKey(key, HKEY_LOCAL_MACHINE, k_Approved, wow);
      if (res != ERROR_SUCCESS) return res;
      res = key.SetValue(k_Clsid, k_ShellExtName);
      if (res != ERROR_SUCCESS) return res;
    }
  }
  else
  {
    CSysString s2 (s);
    s2 += "\\InprocServer32";

    res = MyRegistry_DeleteKey_HKCR(s2, wow);
    if (res != ERROR_SUCCESS && res != ERROR_FILE_NOT_FOUND) return res;
    res = MyRegistry_DeleteKey_HKCR(s, wow);
    if (res == ERROR_FILE_NOT_FOUND) res = ERROR_SUCCESS;
  }
  }

  // shellex items probably are shared beween 32-bit and 64-bit apps. So we don't delete items for delete operation.
  if (setMode)
  for (unsigned i = 0; i < 2; i++)
  {
    for (unsigned k = 0; k < Z7_ARRAY_SIZE(k_shellex_Prefixes); k++)
    {
      CSysString s (k_shellex_Prefixes[k]);
      s += (i == 0 ? k_KeyPostfix_ContextMenu : k_KeyPostfix_DragDrop);
      if (k_shellex_Statuses[i][k])
      {
        CKey key;
        res = MyCreateKey(key, HKEY_CLASSES_ROOT, s, wow);
        if (res != ERROR_SUCCESS) return res;
        res = key.SetValue(NULL, k_Clsid);
        if (res != ERROR_SUCCESS) return res;
      }
      else
      {
        res = MyRegistry_DeleteKey_HKCR(s, wow);
        if (res == ERROR_FILE_NOT_FOUND) res = ERROR_SUCCESS;
        if (res != ERROR_SUCCESS) return res;
      }
    }
  }

  return res;
}


LONG SetContextMenuHandler_All(bool setMode)
{
  return SetContextMenuHandler_State(setMode ? 3 : 0);
}

LONG SetContextMenuHandler_State(unsigned mask)
{
  const FString prefix = NDLL::GetModuleDirPrefix();
  LONG lastRes = ERROR_SUCCESS;
  bool found = false;

  for (unsigned d = 0; d < 2; d++)
  {
    FString path = prefix;
    path += (d == 0 ? "RoxaZipShell.dll" :
        #ifdef _WIN64
          "RoxaZipShell32.dll"
        #else
          "RoxaZipShell64.dll"
        #endif
        );
    if (!NFile::NFind::DoesFileExist_Raw(path))
      continue;
    found = true;

    UInt32 wow = 0;
    if (d == 1)
      wow =
          #ifdef _WIN64
            KEY_WOW64_32KEY
          #else
            KEY_WOW64_64KEY
          #endif
          ;

    const bool enable = (mask & (1u << d)) != 0;
    if (enable ? CheckContextMenuHandler_Complete(fs2us(path), wow)
        : !CheckContextMenuHandler_Dll(fs2us(path), wow))
      continue;
    const LONG res = SetContextMenuHandler(enable, fs2us(path), wow);
    if (res != ERROR_SUCCESS)
      lastRes = res;
  }

  if (!found)
    return ERROR_FILE_NOT_FOUND;
  return lastRes;
}

#endif

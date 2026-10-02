/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
// Redirect both predefined roots into a disposable HKCU key, in this process only.
#include "../CPP/Common/Common.h"
#include "../CPP/Common/MyString.h"
#include "../CPP/Windows/DLL.h"
#include "../CPP/Windows/FileFind.h"
#include "../CPP/7zip/UI/Explorer/RegistryContextMenu.h"
#include <cassert>
#include <cstdio>

// Simulate two installed DLLs without loading a shell extension or requiring UAC.
namespace NWindows {
namespace NDLL { FString GetModuleDirPrefix() { return FTEXT("C:\\RegistryTest\\"); } }
namespace NFile { namespace NFind { bool DoesFileExist_Raw(CFSTR) { return true; } } }
}
int main()
{
  wchar_t name[128];
  swprintf_s(name, L"Software\\7ZipContextMenuTest-%lu-%llu", GetCurrentProcessId(), GetTickCount64());
  HKEY root = NULL;
  assert(RegCreateKeyExW(HKEY_CURRENT_USER, name, 0, NULL, 0, KEY_ALL_ACCESS, NULL, &root, NULL) == ERROR_SUCCESS);
  assert(RegOverridePredefKey(HKEY_CLASSES_ROOT, root) == ERROR_SUCCESS);
  assert(RegOverridePredefKey(HKEY_LOCAL_MACHINE, root) == ERROR_SUCCESS);
  const UString path(L"C:\\RegistryTest\\RoxaZipShell.dll");
  assert(SetContextMenuHandler_State(1) == ERROR_SUCCESS);
  assert(CheckContextMenuHandler_Complete(path));
  const wchar_t *missing[] = {
    L"Folder\\shellex\\ContextMenuHandlers\\RoxaZip",
    L"Directory\\shellex\\ContextMenuHandlers\\RoxaZip",
    L"Directory\\shellex\\DragDropHandlers\\RoxaZip",
    L"Drive\\shellex\\DragDropHandlers\\RoxaZip",
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Shell Extensions\\Approved",
    L"*\\shellex\\ContextMenuHandlers\\RoxaZip"
  };
  for (unsigned i = 0; i < sizeof(missing)/sizeof(missing[0]); i++)
  {
    assert(RegDeleteKeyW(root, missing[i]) == ERROR_SUCCESS);
    assert(!CheckContextMenuHandler_Complete(path));
    assert(SetContextMenuHandler_State(1) == ERROR_SUCCESS);
    assert(CheckContextMenuHandler_Complete(path));
  }
  // A missing '*' key must not hide ownership when disabling a broken menu.
  assert(RegDeleteKeyW(root, missing[5]) == ERROR_SUCCESS);
  assert(SetContextMenuHandler_State(0) == ERROR_SUCCESS);
  assert(!CheckContextMenuHandler_Dll(path));
  // Disabling this installation must not remove a different installation's DLL.
  const UString other(L"C:\\Other\\RoxaZipShell.dll");
  assert(SetContextMenuHandler(true, other) == ERROR_SUCCESS);
  assert(SetContextMenuHandler_State(0) == ERROR_SUCCESS);
  assert(CheckContextMenuHandler_Dll(other));
  assert(RegOverridePredefKey(HKEY_CLASSES_ROOT, NULL) == ERROR_SUCCESS);
  assert(RegOverridePredefKey(HKEY_LOCAL_MACHINE, NULL) == ERROR_SUCCESS);
  assert(RegDeleteTreeW(root, NULL) == ERROR_SUCCESS);
  RegCloseKey(root);
  assert(RegDeleteKeyW(HKEY_CURRENT_USER, name) == ERROR_SUCCESS);
  puts("PASS: missing handler/Approved repair, broken-menu removal and DLL ownership");
}

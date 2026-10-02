/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
// probe-modern-menu.cpp
//
// Native probe for the context menu of RoxaZip. It calls the shell extension
// exactly like the shell does:
//   * the classic path  : IShellExtInit::Initialize + IContextMenu::QueryContextMenu
//                         (with and without HMENU), the inserted item texts are dumped
//   * the modern path   : IExplorerCommand (GetTitle / GetFlags / EnumSubCommands)
//
// Build (from a Visual Studio command prompt):
//   cl /nologo /EHsc /W4 probe-modern-menu.cpp /link shell32.lib ole32.lib user32.lib

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <shellapi.h>
#include <stdio.h>

// {3878DDB7-37F6-4265-BB4F-835DC2A790ED} - CLSID_CZipContextMenu of RoxaZip
static const GUID CLSID_ZipZS =
  { 0x3878DDB7, 0x37F6, 0x4265, { 0xBB, 0x4F, 0x83, 0x5D, 0xC2, 0xA7, 0x90, 0xED } };

static void Print(const char *name, HRESULT hr)
{
  printf("%-46s hr=0x%08X%s\n", name, (unsigned)hr,
      (hr >= 0 && (hr & 0xFFFF) != 0) ? "  (success, code in low word)" : "");
}

// printf("%ws") drops non-ASCII characters with the default "C" locale, so wide
// strings are written as UTF-8 bytes instead.
static void PrintW(const wchar_t *s)
{
  if (!s) { fputs("(null)", stdout); return; }
  char buf[8192];
  const int n = WideCharToMultiByte(CP_UTF8, 0, s, -1, buf, (int)sizeof(buf), NULL, NULL);
  if (n > 1)
    fwrite(buf, 1, (size_t)(n - 1), stdout);
}

int wmain(int argc, wchar_t **argv)
{
  CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);

  const wchar_t *path = (argc > 1) ? argv[1] : L"C:\\Windows\\win.ini";

  printf("target file: %ws\n\n", path);

  // ---------------------------------------------------------- classic path ----
  printf("== classic path: IShellExtInit + IContextMenu ==\n");
  {
    IContextMenu *cm = NULL;
    HRESULT hr = CoCreateInstance(CLSID_ZipZS, NULL, CLSCTX_ALL, IID_IContextMenu, (void **)&cm);
    Print("CoCreateInstance(IID_IContextMenu)", hr);
    if (cm)
    {
      // the shell initializes the handler with the selected items first
      PIDLIST_ABSOLUTE pidl = NULL;
      hr = SHParseDisplayName(path, NULL, &pidl, 0, NULL);
      Print("SHParseDisplayName", hr);
      IShellExtInit *sei = NULL;
      hr = cm->QueryInterface(IID_IShellExtInit, (void **)&sei);
      Print("QueryInterface(IShellExtInit)", hr);
      if (pidl && sei)
      {
        IDataObject *pdo = NULL;
        PIDLIST_ABSOLUTE pidlParent = ILClone(pidl);
        ILRemoveLastID(pidlParent);
        PCUITEMID_CHILD child = ILFindLastID(pidl);
        hr = SHCreateDataObject(pidlParent, 1, &child, NULL, IID_IDataObject, (void **)&pdo);
        Print("SHCreateDataObject", hr);
        if (pdo)
        {
          hr = sei->Initialize(NULL, pdo, NULL);
          Print("IShellExtInit::Initialize", hr);
          pdo->Release();
        }
        ILFree(pidlParent);
      }

      HMENU menu = CreatePopupMenu();
      HRESULT hr2 = cm->QueryContextMenu(menu, 0, 1, 0x7FFE, CMF_NORMAL);
      printf("%-46s hr=0x%08X  code(low word)=%u  menu items=%d\n",
          "QueryContextMenu(real HMENU)", (unsigned)hr2, (unsigned)(hr2 & 0xFFFF),
          GetMenuItemCount(menu));
      {
        const int n = GetMenuItemCount(menu);
        wchar_t buf[512];
        for (int i = 0; i < n; i++)
        {
          buf[0] = 0;
          GetMenuStringW(menu, i, buf, 500, MF_BYPOSITION);
          const bool isSub = (GetMenuState(menu, i, MF_BYPOSITION) & MF_POPUP) != 0;
          printf("    menu[%d] = '", i);
          PrintW(buf);
          printf("'%s\n", isSub ? "   (submenu)" : "");
          if (isSub)
          {
            HMENU sub = GetSubMenu(menu, i);
            const int m = sub ? GetMenuItemCount(sub) : 0;
            printf("        submenu has %d items:\n", m);
            for (int k = 0; k < m; k++)
            {
              buf[0] = 0;
              GetMenuStringW(sub, k, buf, 500, MF_BYPOSITION);
              printf("          [%2d] '", k);
              PrintW(buf);
              printf("'%s\n", (GetMenuState(sub, k, MF_BYPOSITION) & MF_POPUP) ? "   (submenu)" : "");
              if (GetMenuState(sub, k, MF_BYPOSITION) & MF_POPUP)
              {
                HMENU sub2 = GetSubMenu(sub, k);
                const int m2 = sub2 ? GetMenuItemCount(sub2) : 0;
                printf("              (2nd level) %d item(s)", m2);
                if (m2 == 0) printf("   <== EMPTY");
                printf("\n");
                for (int j = 0; j < m2; j++)
                {
                  buf[0] = 0;
                  GetMenuStringW(sub2, j, buf, 500, MF_BYPOSITION);
                  printf("                [%2d] '", j);
                  PrintW(buf);
                  printf("'\n");
                }
              }
            }
          }
        }
      }
      DestroyMenu(menu);

      HRESULT hr3 = cm->QueryContextMenu(NULL, 0, 0, 999, CMF_NORMAL);
      printf("%-46s hr=0x%08X  code(low word)=%u\n",
          "QueryContextMenu(NULL HMENU)", (unsigned)hr3, (unsigned)(hr3 & 0xFFFF));
      if (sei) sei->Release();
      cm->Release();
    }
  }

  // ----------------------------------------------------------- modern path ----
  printf("\n== modern path: IExplorerCommand ==\n");
  {
    IShellItem *item = NULL;
    HRESULT hr = SHCreateItemFromParsingName(path, NULL, IID_IShellItem, (void **)&item);
    if (FAILED(hr) || !item) { printf("SHCreateItemFromParsingName failed 0x%08X\n", (unsigned)hr); return 1; }
    IShellItemArray *items = NULL;
    hr = SHCreateShellItemArrayFromShellItem(item, IID_IShellItemArray, (void **)&items);
    if (FAILED(hr) || !items) { printf("SHCreateShellItemArrayFromShellItem failed 0x%08X\n", (unsigned)hr); return 1; }

    IExplorerCommand *ec = NULL;
    hr = CoCreateInstance(CLSID_ZipZS, NULL, CLSCTX_ALL, IID_IExplorerCommand, (void **)&ec);
    Print("CoCreateInstance(IID_IExplorerCommand)", hr);
    if (ec)
    {
      LPWSTR title = NULL;
      hr = ec->GetTitle(items, &title);
      printf("%-46s hr=0x%08X  title='", "GetTitle", (unsigned)hr);
      PrintW(title ? title : L"(null)");
      printf("'\n");
      CoTaskMemFree(title);

      EXPCMDFLAGS flags = ECF_DEFAULT;
      hr = ec->GetFlags(&flags);
      printf("%-46s hr=0x%08X  flags=0x%X  HASSUBCOMMANDS=%s\n", "GetFlags", (unsigned)hr,
          (unsigned)flags, (flags & ECF_HASSUBCOMMANDS) ? "yes" : "no");

      EXPCMDSTATE state = ECS_ENABLED;
      hr = ec->GetState(items, FALSE, &state);
      printf("%-46s hr=0x%08X  state=0x%X\n", "GetState", (unsigned)hr, (unsigned)state);

      IEnumExplorerCommand *en = NULL;
      hr = ec->EnumSubCommands(&en);
      Print("EnumSubCommands", hr);
      if (en)
      {
        en->Reset();
        unsigned n = 0;
        for (;;)
        {
          IExplorerCommand *sub = NULL;
          ULONG fetched = 0;
          HRESULT hrN = en->Next(1, &sub, &fetched);
          if (fetched == 0 || !sub) break;
          n++;
          LPWSTR t = NULL;
          sub->GetTitle(items, &t);
          EXPCMDFLAGS f = ECF_DEFAULT;
          sub->GetFlags(&f);
          printf("    [%2u]%s ", n, (f & ECF_HASSUBCOMMANDS) ? " >" : "  ");
          PrintW(t ? t : L"(separator)");
          printf("\n");
          // second level: does the cascade of this item have children?
          if (f & ECF_HASSUBCOMMANDS)
          {
            // The shell may enumerate the children more than once (menu sizing,
            // flyout rendering) and it may or may not call Reset()/Clone().
            // Three variants are tested here:
            //   pass 1: EnumSubCommands + Reset  + Next
            //   pass 2: EnumSubCommands          + Next   (no Reset - this is what
            //           a consumer expects to work if every enumeration is a
            //           fresh enumerator object)
            //   pass 3: Clone() of the enumerator + Next
            for (int pass = 1; pass <= 3; pass++)
            {
              IEnumExplorerCommand *en2 = NULL;
              const HRESULT hr2 = sub->EnumSubCommands(&en2);
              unsigned n2 = 0;
              unsigned nested = 0;   // children that are submenus themselves
              printf("          pass %d: EnumSubCommands -> hr=0x%08X", pass, (unsigned)hr2);

              if (pass == 3)
              {
                IEnumExplorerCommand *clone = NULL;
                if (en2)
                {
                  const HRESULT hrC = en2->Clone(&clone);
                  printf("   Clone -> hr=0x%08X", (unsigned)hrC);
                  en2->Release();
                  en2 = clone;
                  if (!en2) { printf("\n          Clone FAILED -> a consumer that clones gets no items\n"); continue; }
                }
              }

              if (en2)
              {
                if (pass == 1) en2->Reset();
                for (;;)
                {
                  IExplorerCommand *sub2 = NULL;
                  ULONG fetched2 = 0;
                  if (en2->Next(1, &sub2, &fetched2) != S_OK || fetched2 == 0 || !sub2) break;
                  n2++;
                  EXPCMDFLAGS f2 = ECF_DEFAULT;
                  sub2->GetFlags(&f2);
                  if (f2 & ECF_HASSUBCOMMANDS) nested++;
                  if (pass == 1 && n2 <= 3)
                  {
                    LPWSTR t2 = NULL;
                    sub2->GetTitle(items, &t2);
                    printf("\n            [%2u]%s ", n2, (f2 & ECF_HASSUBCOMMANDS) ? " >" : "  ");
                    PrintW(t2 ? t2 : L"(separator)");
                    CoTaskMemFree(t2);
                  }
                  sub2->Release();
                }
                en2->Release();
              }
              printf("\n          children (pass %d): %u%s%s\n", pass, n2,
                  (pass > 1 && n2 == 0) ? "   <== EMPTY - this is what the shell sees!" : "",
                  ((pass == 1 && nested) ? "   (items that are submenus themselves - the Windows 11 flyout cannot render them)" : ""));
            }
          }
          CoTaskMemFree(t);
          sub->Release();
        }
        printf("    sub-commands: %u\n", n);
        en->Release();
      }
      ec->Release();
    }
    items->Release();
    item->Release();
  }

  // --------------------------------------- shell-built classic menu ----------
  // This is the menu that Windows builds for "Show more options": all registered
  // handlers (classic ContextMenuHandlers *and* packaged fileExplorerContextMenus).
  printf("\n== shell classic menu ('Show more options') ==\n");
  {
    PIDLIST_ABSOLUTE pidl = NULL;
    if (SUCCEEDED(SHParseDisplayName(path, NULL, &pidl, 0, NULL)) && pidl)
    {
      IShellFolder *folder = NULL;
      PCUITEMID_CHILD child = NULL;
      if (SUCCEEDED(SHBindToParent(pidl, IID_IShellFolder, (void **)&folder, &child)) && folder)
      {
        IContextMenu *shellMenu = NULL;
        if (SUCCEEDED(folder->GetUIObjectOf(NULL, 1, &child, IID_IContextMenu, NULL, (void **)&shellMenu)) && shellMenu)
        {
          HMENU menu = CreatePopupMenu();
          const HRESULT hr = shellMenu->QueryContextMenu(menu, 0, 1, 0x7FFE, CMF_NORMAL);
          const int n = GetMenuItemCount(menu);
          printf("shell QueryContextMenu hr=0x%08X  items=%d\n", (unsigned)hr, n);
          int found = 0;
          wchar_t buf[512];
          for (int i = 0; i < n; i++)
          {
            buf[0] = 0;
            const bool isSub = (GetMenuState(menu, i, MF_BYPOSITION) & MF_POPUP) != 0;
            if (isSub) GetMenuStringW(GetSubMenu(menu, i), 0, buf, 1, MF_BYPOSITION); // touch
            buf[0] = 0;
            GetMenuStringW(menu, i, buf, 500, MF_BYPOSITION);
            if (wcsstr(buf, L"RoxaZip"))
            {
              found++;
              printf("    [%2d] '", i);
              PrintW(buf);
              printf("'%s   <== RoxaZip entry #%d\n", isSub ? "   (submenu)" : "", found);
            }
          }
          printf("    RoxaZip entries in the classic menu: %d\n", found);
          DestroyMenu(menu);
          shellMenu->Release();
        }
        folder->Release();
      }
      ILFree(pidl);
    }
  }

  CoUninitialize();
  return 0;
}

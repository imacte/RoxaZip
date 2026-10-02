// SystemPage.cpp

#include "StdAfx.h"

#include "../../../Common/MyWindows.h"

#if defined(__MINGW32__) || defined(__MINGW64__)
#include <shlobj.h>
#else
#include <ShlObj.h>
#endif

#include "../../../Common/Defs.h"
#include "../../../Common/MyCom.h"
#include "../../../Common/StringConvert.h"

#include "../../../Windows/DLL.h"
#include "../../../Windows/ErrorMsg.h"
#include "../../../Windows/Registry.h"

#include <shellapi.h>
#include <shlwapi.h>

#include "HelpUtils.h"
#include "IFolder.h"
#include "LangUtils.h"
#include "PropertyNameRes.h"
#include "ShellIntegrationModern.h"
#include "SystemPage.h"
#include "AssocCommand.h"
#include "ShellOperationWait.h"
#include "SystemPageRes.h"

using namespace NWindows;

#ifndef _UNICODE
extern bool g_IsNT;
#endif

#ifdef Z7_LANG
static const UInt32 kLangIDs[] =
{
  IDT_SYSTEM_ASSOCIATE
};
#endif

#define kSystemTopic "FM/options.htm#system"

CSysString CModifiedExtInfo::GetString() const
{
  const char *s;
  if (State == kExtState_7Zip)
    s = "RoxaZip";
  else if (State == kExtState_Clear)
    s = "";
  else if (Other7Zip)
    s = "[RoxaZip]";
  else
    return ProgramKey;
  return CSysString (s);
}


int CSystemPage::AddIcon(const UString &iconPath, int iconIndex)
{
  if (iconPath.IsEmpty())
    return -1;
  if (iconIndex == -1)
    iconIndex = 0;
  
  HICON hicon;
  
  #ifdef UNDER_CE
  ExtractIconExW(iconPath, iconIndex, NULL, &hicon, 1);
  if (!hicon)
  #else
  // we expand path from REG_EXPAND_SZ registry item.
  UString path;
  const DWORD size = MAX_PATH + 10;
  const DWORD needLen = ::ExpandEnvironmentStringsW(iconPath, path.GetBuf(size + 2), size);
  path.ReleaseBuf_CalcLen(size);
  if (needLen == 0 || needLen >= size)
    path = iconPath;
  const UINT num = ExtractIconExW(path, iconIndex, NULL, &hicon, 1);
  if (num != 1 || !hicon)
  #endif
    return -1;
  
  _imageList.AddIcon(hicon);
  DestroyIcon(hicon);
  return (int)(_numIcons++);
}


void CSystemPage::RefreshListItem(unsigned group, unsigned listIndex)
{
  const CAssoc &assoc = _items[GetRealIndex(listIndex)];
  _listView.SetSubItem(listIndex, group + 1, assoc.Pair[group].GetString());
  LVITEMW newItem;
  memset(&newItem, 0, sizeof(newItem));
  newItem.iItem = (int)listIndex;
  newItem.mask = LVIF_IMAGE;
  newItem.iImage = assoc.GetIconIndex();
  _listView.SetItem(&newItem);
}


void CSystemPage::ChangeState(unsigned group, const CUIntVector &indices)
{
  if (indices.IsEmpty())
    return;

  bool thereAreClearItems = false;
  unsigned counters[3] = { 0, 0, 0 };
  
  unsigned i;
  for (i = 0; i < indices.Size(); i++)
  {
    const CModifiedExtInfo &mi = _items[GetRealIndex(indices[i])].Pair[group];
    int state = kExtState_7Zip;
    if (mi.State == kExtState_7Zip)
      state = kExtState_Clear;
    else if (mi.State == kExtState_Clear)
    {
      thereAreClearItems = true;
      if (mi.Other)
        state = kExtState_Other;
    }
    counters[state]++;
  }

  int state = kExtState_Clear;
  if (counters[kExtState_Other] != 0)
    state = kExtState_Other;
  else if (counters[kExtState_7Zip] != 0)
    state = kExtState_7Zip;
  
  for (i = 0; i < indices.Size(); i++)
  {
    unsigned listIndex = indices[i];
    CAssoc &assoc = _items[GetRealIndex(listIndex)];
    CModifiedExtInfo &mi = assoc.Pair[group];
    bool change = false;
    
    switch (state)
    {
      case kExtState_Clear: change = true; break;
      case kExtState_Other: change = mi.Other; break;
      default: change = !(mi.Other && thereAreClearItems); break;
    }
    
    if (change)
    {
      mi.State = state;
      RefreshListItem(group, listIndex);
    }
  }
  
  _needSave = true;
  Changed();
}


bool CSystemPage::OnInit()
{
  _needSave = false;

#ifdef Z7_LANG
  LangSetDlgItems(*this, kLangIDs, Z7_ARRAY_SIZE(kLangIDs));
#endif

  _listView.Attach(GetItem(IDL_SYSTEM_ASSOCIATE));
  _listView.SetUnicodeFormat();
  DWORD newFlags = LVS_EX_FULLROWSELECT;
  _listView.SetExtendedListViewStyle(newFlags, newFlags);

  _numIcons = 0;
  _imageList.Create(16, 16, ILC_MASK | ILC_COLOR32, 0, 0);

  _listView.SetImageList(_imageList, LVSIL_SMALL);

  _listView.InsertColumn(0, LangString(IDS_PROP_FILE_TYPE), 80);

  UString s;

  #if NUM_EXT_GROUPS == 1
    s = "Program";
  #else
    #ifndef UNDER_CE
      const unsigned kSize = 256;
      BOOL res;

      DWORD size = kSize;

      #ifndef _UNICODE
      if (!g_IsNT)
      {
        AString s2;
        res = GetUserNameA(s2.GetBuf(size), &size);
        s2.ReleaseBuf_CalcLen(MyMin((unsigned)size, kSize));
        s = GetUnicodeString(s2);
      }
      else
      #endif
      {
        res = GetUserNameW(s.GetBuf(size), &size);
        s.ReleaseBuf_CalcLen(MyMin((unsigned)size, kSize));
      }
    
      if (!res)
    #endif
        s = "Current User";
  #endif

  LV_COLUMNW ci;
  ci.mask = LVCF_TEXT | LVCF_FMT | LVCF_WIDTH | LVCF_SUBITEM;
  ci.cx = 152;
  ci.fmt = LVCFMT_CENTER;
  ci.pszText = s.Ptr_non_const();
  ci.iSubItem = 1;
  _listView.InsertColumn(1, &ci);

  #if NUM_EXT_GROUPS > 1
  {
    LangString(IDS_SYSTEM_ALL_USERS, s);
    ci.pszText = s.Ptr_non_const();
    ci.iSubItem = 2;
    _listView.InsertColumn(2, &ci);
  }

  {
    /* RoxaZip: the effective default app of Windows 10+ (UserChoice) is shown
       in an extra column, because the columns above only hold the classic ProgID
       which Windows ignores as soon as a UserChoice exists. */
    UString t (L"\u7CFB\u7EDF\u9ED8\u8BA4\u7A0B\u5E8F");   // "system default app"
    ci.pszText = t.Ptr_non_const();
    ci.iSubItem = 3;
    ci.cx = 140;
    _listView.InsertColumn(3, &ci);
  }
  #endif

  _extDB.Read();
  _items.Clear();

  FOR_VECTOR (i, _extDB.Exts)
  {
    const CExtPlugins &extInfo = _extDB.Exts[i];

    LVITEMW item;
    item.iItem = (int)i;
    item.mask = LVIF_TEXT | LVIF_PARAM | LVIF_IMAGE;
    item.lParam = (LPARAM)i;
    item.iSubItem = 0;
    // ListView always uses internal iImage that is 0 by default?
    // so we always use LVIF_IMAGE.
    item.iImage = -1;
    item.pszText = extInfo.Ext.Ptr_non_const();

    CAssoc assoc;
    const CPluginToIcon &plug = extInfo.Plugins[0];
    assoc.SevenZipImageIndex = AddIcon(plug.IconPath, plug.IconIndex);

    CSysString texts[NUM_EXT_GROUPS];
    unsigned g;
    for (g = 0; g < NUM_EXT_GROUPS; g++)
    {
      CModifiedExtInfo &mi = assoc.Pair[g];
      mi.ReadFromRegistry(GetHKey(g), GetSystemString(extInfo.Ext));
      mi.SetState(plug.IconPath);
      mi.ImageIndex = AddIcon(mi.IconPath, mi.IconIndex);
      texts[g] = mi.GetString();
    }
    item.iImage = assoc.GetIconIndex();
    const int itemIndex = _listView.InsertItem(&item);
    for (g = 0; g < NUM_EXT_GROUPS; g++)
      _listView.SetSubItem((unsigned)itemIndex, 1 + g, texts[g]);
    _items.Add(assoc);
  }
  
  if (_listView.GetItemCount() > 0)
    _listView.SetItemState(0, LVIS_FOCUSED, LVIS_FOCUSED);

  /* the list columns are not touched here: they keep the widths from OnInit()
     (80/152/152/140 pixels). The "+" buttons are placed above the column they act
     on - which has to happen after the property sheet has laid the page out (it
     scales the controls after OnInit()), so it runs from a timer and on resize. */
  Position_MenuButtons();

  return CPropertyPage::OnInit();
}


/* Places the two "+" buttons above the column they act on.

   The columns keep their widths from OnInit() (80/152/152/140 pixels) - only the
   buttons are moved here. That has to happen after the property sheet has laid
   the page out (it scales the controls after OnInit()), which is why this runs
   from a timer a few times and whenever the page is resized. */
void CSystemPage::Position_MenuButtons()
{
  RECT rList;
  ::GetWindowRect(HWND(_listView), &rList);
  POINT pList = { rList.left, rList.top };
  ::ScreenToClient(*this, &pList);

  int x = pList.x;
  for (unsigned g = 0; g < NUM_EXT_GROUPS; g++)
  {
    const HWND h = GetItem(g == 0 ? IDB_SYSTEM_CURRENT : IDB_SYSTEM_ALL);
    RECT rb;
    ::GetWindowRect(h, &rb);

    /* the columns in front of this one are accumulated here (the file type column
       for the first button, plus the current user column for the second), then
       the width of the column this button belongs to is used */
    x += (int)::SendMessage(HWND(_listView), LVM_GETCOLUMNWIDTH, (WPARAM)g, 0);
    const int w = (int)::SendMessage(HWND(_listView), LVM_GETCOLUMNWIDTH, (WPARAM)(g + 1), 0);

    ::SetWindowPos(h, NULL, x, pList.y - (rb.bottom - rb.top) - 2, w, rb.bottom - rb.top,
        SWP_NOZORDER | SWP_NOACTIVATE);
  }
}


/* Let Windows change the default only after the user confirms, without creating
   a sample file or launching an archive application. */
void CSystemPage::OpenDefaultAppDialog(unsigned listIndex)
{
  const unsigned realIndex = GetRealIndex(listIndex);
  if (realIndex >= _extDB.Exts.Size())
    return;

  #ifndef UNDER_CE
  // Windows 10/11 owns the confirmation and cancellation of default changes.
  if ((INT_PTR)::ShellExecuteW(*this, L"open",
      L"ms-settings:defaultapps?registeredAppMachine=7-Zip%20ZS",
      NULL, NULL, SW_SHOWNORMAL) > 32)
    return;
  const UString ext = UString(L".") + _extDB.Exts[realIndex].Ext;
  // Load dynamically so the file manager can still start on older Windows.
  const HMODULE shell = ::GetModuleHandleW(L"shell32.dll");
  if (shell)
  {
    typedef HRESULT (WINAPI *Func_SHOpenWithDialog)(HWND, const OPENASINFO *);
    const Func_SHOpenWithDialog show = Z7_GET_PROC_ADDRESS(
        Func_SHOpenWithDialog, shell, "SHOpenWithDialog");
    if (show)
    {
      OPENASINFO info = {};
      info.pcszFile = ext;
      info.oaifInFlags = OAIF_REGISTER_EXT | OAIF_FORCE_REGISTRATION;
      const HRESULT hr = show(*this, &info);
      UpdateSystemDefaults();
      if (SUCCEEDED(hr) || hr == HRESULT_FROM_WIN32(ERROR_CANCELLED))
        return;
    }
  }
  ::ShellExecuteW(*this, L"open", L"ms-settings:defaultapps", NULL, NULL, SW_SHOWNORMAL);
  #endif
}


/* Deletes the "UserChoice" value of one file type.

   Windows 10/11 ignores the classic ProgID as soon as a UserChoice exists, and
   an application cannot write that value (it is protected by a hash). Removing it
   is the way to make the classic association of this program effective again;
   Windows then falls back to the ProgID that the page below writes. */
void CSystemPage::ResetSystemDefault(unsigned listIndex)
{
  const unsigned realIndex = GetRealIndex(listIndex);
  if (realIndex >= _extDB.Exts.Size())
    return;

  UString keyName = L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FileExts\\.";
  keyName += _extDB.Exts[realIndex].Ext;
  keyName += L"\\UserChoice";

  const LONG res = ::RegDeleteKeyW(HKEY_CURRENT_USER, keyName.Ptr());
  if (res != ERROR_SUCCESS && res != ERROR_FILE_NOT_FOUND)
  {
    UString m (L"\u65E0\u6CD5\u5220\u9664 UserChoice\uFF1A");   // "cannot delete UserChoice:"
    m.Add_LF();
    m += NError::MyFormatMessage(res);
    MessageBoxW(*this, m.Ptr(), L"RoxaZip", MB_ICONERROR);
    return;
  }

  #ifndef UNDER_CE
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, NULL, NULL);
  #endif

  UpdateSystemDefaults();
}


// The worker owns its input and output; it never touches the page or its HWND.
// Closing the dialog drops the UI reference without waiting for shell handlers.
struct CSystemDefaultsJob
{
  LONG References, Done, Cancel;
  UStringVector Exts, Names;
  CSystemDefaultsJob(): References(1), Done(0), Cancel(0) {}
  void Release() { if (::InterlockedDecrement(&References) == 0) delete this; }
  static DWORD WINAPI Run(LPVOID param)
  {
    CSystemDefaultsJob *job = (CSystemDefaultsJob *)param;
    const HRESULT apartment = ::CoInitializeEx(NULL, COINIT_MULTITHREADED);
    try
    {
      FOR_VECTOR (i, job->Exts)
      {
        if (::InterlockedCompareExchange(&job->Cancel, 0, 0)) break;
        UString name;
        #ifndef UNDER_CE
        wchar_t buffer[512] = {};
        DWORD size = Z7_ARRAY_SIZE(buffer);
        HRESULT hr = AssocQueryStringW(ASSOCF_NOTRUNCATE, ASSOCSTR_FRIENDLYAPPNAME,
            job->Exts[i], L"open", buffer, &size);
        if (SUCCEEDED(hr)) name = buffer;
        else if (hr == E_POINTER && size > Z7_ARRAY_SIZE(buffer))
        {
          hr = AssocQueryStringW(ASSOCF_NOTRUNCATE, ASSOCSTR_FRIENDLYAPPNAME,
              job->Exts[i], L"open", name.GetBuf(size), &size);
          if (SUCCEEDED(hr)) name.ReleaseBuf_CalcLen(size);
          else name.ReleaseBuf_SetLen(0);
        }
        #endif
        job->Names.Add(name);
      }
    }
    catch (...) {} // A failed lookup must not take down the options dialog.
    if (SUCCEEDED(apartment)) ::CoUninitialize();
    ::InterlockedExchange(&job->Done, 1);
    job->Release();
    return 0;
  }
};

#ifndef UNDER_CE
static const UINT kRefreshDefaults = WM_APP + 107;
static LRESULT CALLBACK DefaultsSheetProc(HWND hwnd, UINT message, WPARAM wParam,
    LPARAM lParam, UINT_PTR id, DWORD_PTR data)
{
  if ((message == WM_ACTIVATE && LOWORD(wParam) != WA_INACTIVE)
      || message == WM_SETTINGCHANGE)
    ::PostMessage((HWND)data, kRefreshDefaults, 0, 0);
  if (message == WM_NCDESTROY)
    ::RemoveWindowSubclass(hwnd, DefaultsSheetProc, id);
  return ::DefSubclassProc(hwnd, message, wParam, lParam);
}
#endif

void CSystemPage::UpdateSystemDefaults()
{
  _defaultsLoaded = false;
  if (_defaultsJob) { _defaultsPending = true; return; }
  CSystemDefaultsJob *job = new CSystemDefaultsJob;
  try
  {
    FOR_VECTOR (i, _extDB.Exts)
      job->Exts.Add(UString(L".") + _extDB.Exts[i].Ext);
  }
  catch (...) { job->Release(); throw; }
  if (!::SetTimer(*this, 2, 50, NULL)) { job->Release(); return; }
  ::InterlockedIncrement(&job->References);
  HANDLE thread = ::CreateThread(NULL, 0, CSystemDefaultsJob::Run, job, 0, NULL);
  if (!thread)
  {
    ::KillTimer(*this, 2);
    job->Release(); job->Release();
    return;
  }
  _defaultsJob = job;
  ::CloseHandle(thread);
}

bool CSystemPage::OnMessage(UINT message, WPARAM wParam, LPARAM lParam)
{
  #ifndef UNDER_CE
  if (message == kRefreshDefaults)
  {
    _defaultsLoaded = false;
    if (_defaultsJob) _defaultsPending = true;
    else if (::IsWindowVisible(*this)) UpdateSystemDefaults();
    return true;
  }
  #endif
  return CPropertyPage::OnMessage(message, wParam, lParam);
}

bool CSystemPage::OnDestroy()
{
  ::KillTimer(*this, 1);
  ::KillTimer(*this, 2);
  #ifndef UNDER_CE
  ::RemoveWindowSubclass(::GetParent(*this), DefaultsSheetProc, (UINT_PTR)(HWND)*this);
  #endif
  if (_defaultsJob)
  {
    ::InterlockedExchange(&_defaultsJob->Cancel, 1);
    _defaultsJob->Release();
    _defaultsJob = NULL;
  }
  return CPropertyPage::OnDestroy();
}

LONG CSystemPage::OnSetActive()
{
  #ifndef UNDER_CE
  ::SetWindowSubclass(::GetParent(*this), DefaultsSheetProc,
      (UINT_PTR)(HWND)*this, (DWORD_PTR)(HWND)*this);
  #endif
  _alignTicks = 0;
  if (!::SetTimer(*this, 1, 250, NULL)) Position_MenuButtons();
  if (!_defaultsLoaded && !_defaultsJob) UpdateSystemDefaults();
  return false;
}

bool CSystemPage::OnTimer(WPARAM timerID, LPARAM /* lParam */)
{
  if (timerID == 1)
  {
    Position_MenuButtons();
    if (++_alignTicks == 4) ::KillTimer(*this, 1);
    return true;
  }
  if (timerID != 2) return false;
  if (_defaultsJob && ::InterlockedCompareExchange(&_defaultsJob->Done, 0, 0))
  {
    ::KillTimer(*this, 2);
    if (!_defaultsPending)
    {
      FOR_VECTOR (i, _defaultsJob->Names)
      {
        _items[i].SystemDefault = _defaultsJob->Names[i];
        _listView.SetSubItem(i, 1 + NUM_EXT_GROUPS, _items[i].SystemDefault);
      }
      _defaultsLoaded = _defaultsJob->Names.Size() == _items.Size();
    }
    _defaultsJob->Release();
    _defaultsJob = NULL;
    if (_defaultsPending)
    {
      _defaultsPending = false;
      if (::IsWindowVisible(*this)) UpdateSystemDefaults();
    }
  }
  return true;
}


bool CSystemPage::OnSize(WPARAM /* wParam */, int /* xSize */, int /* ySize */)
{
  Position_MenuButtons();
  return false;
}


static UString GetProgramCommand()
{
  UString s ('\"');
  s += fs2us(NDLL::GetModuleDirPrefix());
  s += "RoxaZipFM.exe\" \"%1\"";
  return s;
}


/* Applies one entry of "-AssocAll=..." to HKEY_LOCAL_MACHINE (the "all users"
   group of the system page). */
static void Apply_AssocOne(bool add, const UString &ext, const CExtDatabase &extDB, const UString &command, LONG &res)
{
  if (add)
  {
    const CExtPlugins *found = NULL;
    FOR_VECTOR (i, extDB.Exts)
    {
      if (extDB.Exts[i].Ext.IsEqualTo_NoCase(ext))
      {
        found = &extDB.Exts[i];
        break;
      }
    }
    if (!found || found->Plugins.IsEmpty())
      return;

    UString title = found->Ext;
    title += " Archive";
    const CPluginToIcon &plug = found->Plugins[0];
    const LONG r = NRegistryAssoc::AddShellExtensionInfo(HKEY_LOCAL_MACHINE, ext,
        title, command, plug.IconPath, plug.IconIndex);
    if (r != ERROR_SUCCESS)
      res = r;
  }
  else
  {
    const LONG r = NRegistryAssoc::DeleteShellExtensionInfo(HKEY_LOCAL_MACHINE, ext);
    if (r != ERROR_SUCCESS)
      res = r;
  }
}


struct CAssocAction
{
  UString Ext;
  bool Add;
};

struct CAssocCommandCollector
{
  const CExtDatabase &Database;
  CObjectVector<CAssocAction> Actions;
  CAssocCommandCollector(const CExtDatabase &db): Database(db) {}
  bool operator()(const wchar_t *start, unsigned length, bool add)
  {
    UString ext;
    ext.SetFrom(start, length);
    FOR_VECTOR (i, Database.Exts)
    {
      if (Database.Exts[i].Ext.IsEqualTo_NoCase(ext)
          && !Database.Exts[i].Plugins.IsEmpty())
      {
        CAssocAction action;
        action.Ext = ext;
        action.Add = add;
        Actions.Add(action);
        return true;
      }
    }
    return false;
  }
};

int ApplyAssocAll_FromCommandLine(const wchar_t *spec)
{
  CExtDatabase extDB;
  extDB.Read();
  CAssocCommandCollector collector(extDB);
  if (!ParseAssocCommand(spec, collector)) return 1;
  const UString command = GetProgramCommand();
  LONG res = ERROR_SUCCESS;
  FOR_VECTOR (i, collector.Actions)
  {
    const CAssocAction &action = collector.Actions[i];
    Apply_AssocOne(action.Add, action.Ext, extDB, command, res);
  }
  return res == ERROR_SUCCESS ? 0 : 1;
}


LONG CSystemPage::OnApply()
{
  if (!_needSave)
    return PSNRET_NOERROR;

  CShellOperationGuard guard(*this);
  const UString command = GetProgramCommand();

  /* The "all users" group (group 1) writes to HKEY_LOCAL_MACHINE and therefore
     needs administrator rights. Those changes are collected and given to an
     elevated copy of this program: one UAC prompt, the program itself does not
     have to be restarted as administrator. */
  UString assocAdd, assocDel;
  bool allUsersDone = false;
  if (!NShellIntegrationModern::Is_Process_Elevated())
  {
    FOR_VECTOR (listIndex, _extDB.Exts)
    {
      const unsigned realIndex = GetRealIndex(listIndex);
      const CModifiedExtInfo &mi = _items[realIndex].Pair[1];
      if (mi.OldState == mi.State)
        continue;
      const UString &ext = _extDB.Exts[realIndex].Ext;
      if (mi.State == kExtState_7Zip)
      {
        if (!assocAdd.IsEmpty())
          assocAdd.Add_Char(',');
        assocAdd += ext;
      }
      else if (mi.State == kExtState_Clear)
      {
        if (!assocDel.IsEmpty())
          assocDel.Add_Char(',');
        assocDel += ext;
      }
    }

    if (!assocAdd.IsEmpty() || !assocDel.IsEmpty())
    {
      UString spec (L"-AssocAll=");
      if (!assocAdd.IsEmpty())
      {
        spec.Add_Char('+');
        spec += assocAdd;
      }
      if (!assocDel.IsEmpty())
      {
        spec.Add_Char('-');
        spec += assocDel;
      }

      UString error;
      if (NShellIntegrationModern::Run_Elevated_Self(spec, error, *this) == S_OK)
        allUsersDone = true;
      else
      {
        if (error.IsEmpty())
          error = L"the elevated operation failed";
        MessageBoxW(*this, error.Ptr(), L"RoxaZip", MB_ICONERROR);
        return PSNRET_INVALID_NOCHANGEPAGE;
      }
    }
  }

  if (allUsersDone)
  {
    // the elevated copy has done the group-1 part already
    FOR_VECTOR (listIndex, _extDB.Exts)
    {
      CModifiedExtInfo &mi = _items[GetRealIndex(listIndex)].Pair[1];
      mi.OldState = mi.State;
    }
  }

  LONG res = 0;

  FOR_VECTOR (listIndex, _extDB.Exts)
  {
    unsigned realIndex = GetRealIndex(listIndex);
    const CExtPlugins &extInfo = _extDB.Exts[realIndex];
    CAssoc &assoc = _items[realIndex];

    for (unsigned g = 0; g < NUM_EXT_GROUPS; g++)
    {
      CModifiedExtInfo &mi = assoc.Pair[g];
      HKEY key = GetHKey(g);
      
      if (mi.OldState != mi.State)
      {
        LONG res2 = 0;
        
        if (mi.State == kExtState_7Zip)
        {
          UString title = extInfo.Ext;
          title += " Archive";
          const CPluginToIcon &plug = extInfo.Plugins[0];
          res2 = NRegistryAssoc::AddShellExtensionInfo(key, GetSystemString(extInfo.Ext),
              title, command, plug.IconPath, plug.IconIndex);

          /* RoxaZip: Windows 10/11 ignores the classic ProgID while a UserChoice
             exists for that file type, so that entry is removed as well -
             otherwise setting the association here would have no effect and the
             "system default app" column would keep showing the other program. */
          if (res2 == 0)
          {
            UString userChoiceKey = L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FileExts\\.";
            userChoiceKey += extInfo.Ext;
            userChoiceKey += L"\\UserChoice";
            ::RegDeleteKeyW(HKEY_CURRENT_USER, userChoiceKey.Ptr());
          }
        }
        else if (mi.State == kExtState_Clear)
          res2 = NRegistryAssoc::DeleteShellExtensionInfo(key, GetSystemString(extInfo.Ext));
        
        if (res == 0)
          res = res2;
        if (res2 == 0)
          mi.OldState = mi.State;
        
        mi.State = mi.OldState;
        RefreshListItem(g, listIndex);
      }
    }
  }
  
  #ifndef UNDER_CE
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, NULL, NULL);
  #endif

  WasChanged = true;

  _needSave = false;
  
  if (res != 0)
    MessageBoxW(*this, NError::MyFormatMessage(res), L"RoxaZip", MB_ICONERROR);
  
  return PSNRET_NOERROR;
}


void CSystemPage::OnNotifyHelp()
{
  ShowHelpWindow(kSystemTopic);
}


bool CSystemPage::OnButtonClicked(unsigned buttonID, HWND buttonHWND)
{
  switch (buttonID)
  {
    /*
    case IDC_SYSTEM_SELECT_ALL:
      _listView.SelectAll();
      return true;
    */
    case IDB_SYSTEM_CURRENT:
    case IDB_SYSTEM_ALL:
      ChangeState(buttonID == IDB_SYSTEM_CURRENT ? 0 : 1);
      return true;
  }
  return CPropertyPage::OnButtonClicked(buttonID, buttonHWND);
}


bool CSystemPage::OnNotify(UINT controlID, LPNMHDR lParam)
{
  if (lParam->hwndFrom == HWND(_listView))
  {
    switch (lParam->code)
    {
      case NM_RETURN:
      {
        ChangeState(0);
        return true;
      }

      case NM_DBLCLK:
      {
        // Windows owns confirmation/cancellation of the default app change.
        NMITEMACTIVATE *item = (NMITEMACTIVATE *)lParam;
        if (item->iItem >= 0)
          OpenDefaultAppDialog((unsigned)item->iItem);
        return true;
      }

      case NM_RCLICK:
      {
        /* RoxaZip: right click offers to remove the UserChoice value, which is
           the only way back to the classic association (an application cannot
           write UserChoice itself) */
        NMITEMACTIVATE *item = (NMITEMACTIVATE *)lParam;
        if (item->iItem < 0)
          return true;

        HMENU menu = ::CreatePopupMenu();
        if (!menu)
          return true;
        UString text (L"\u91CD\u7F6E\u7CFB\u7EDF\u9ED8\u8BA4\uFF08\u5220\u9664 UserChoice\uFF09");
        ::AppendMenuW(menu, MF_STRING, 1, text.Ptr());

        POINT pt;
        ::GetCursorPos(&pt);
        const int cmd = (int)::TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
            pt.x, pt.y, 0, *this, NULL);
        ::DestroyMenu(menu);

        if (cmd == 1)
          ResetSystemDefault((unsigned)item->iItem);
        return true;
      }

      case NM_CLICK:
      {
        #ifdef UNDER_CE
        NMLISTVIEW *item = (NMLISTVIEW *)lParam;
        #else
        NMITEMACTIVATE *item = (NMITEMACTIVATE *)lParam;
        if (item->uKeyFlags == 0)
        #endif
        {
          if (item->iItem >= 0)
          {
            // unsigned realIndex = GetRealIndex(item->iItem);
            if (item->iSubItem >= 1 && item->iSubItem <= 2)
            {
              CUIntVector indices;
              indices.Add((unsigned)item->iItem);
              ChangeState(item->iSubItem < 2 ? 0 : 1, indices);
            }
          }
        }
        break;
      }
      
      case LVN_KEYDOWN:
      {
        if (OnListKeyDown(LPNMLVKEYDOWN(lParam)))
          return true;
        break;
      }
      
      /*
      case NM_RCLICK:
      case NM_DBLCLK:
      case LVN_BEGINRDRAG:
        // PostMessage(kRefreshpluginsListMessage, 0);
        PostMessage(kUpdateDatabase, 0);
        break;
      */
    }
  }
  return CPropertyPage::OnNotify(controlID, lParam);
}


void CSystemPage::ChangeState(unsigned group)
{
  CUIntVector indices;
  
  int itemIndex = -1;
  while ((itemIndex = _listView.GetNextSelectedItem(itemIndex)) != -1)
    indices.Add((unsigned)itemIndex);
  
  if (indices.IsEmpty())
    FOR_VECTOR (i, _items)
      indices.Add(i);
  
  ChangeState(group, indices);
}


bool CSystemPage::OnListKeyDown(LPNMLVKEYDOWN keyDownInfo)
{
  bool ctrl = IsKeyDown(VK_CONTROL);
  bool alt = IsKeyDown(VK_MENU);

  if (alt)
    return false;

  if ((ctrl && keyDownInfo->wVKey == 'A')
      || (!ctrl && keyDownInfo->wVKey == VK_MULTIPLY))
  {
    _listView.SelectAll();
    return true;
  }

  switch (keyDownInfo->wVKey)
  {
    case VK_SPACE:
    case VK_ADD:
    case VK_SUBTRACT:
    case VK_SEPARATOR:
    case VK_DIVIDE:

    #ifndef UNDER_CE
    case VK_OEM_PLUS:
    case VK_OEM_MINUS:
    #endif

      if (!ctrl)
      {
        ChangeState(keyDownInfo->wVKey == VK_SPACE ? 0 : 1);
        return true;
      }
      break;
  }

  return false;
}

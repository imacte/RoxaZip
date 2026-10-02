// MenuPage.cpp

#include "StdAfx.h"

#include "../Common/ZipRegistry.h"

#include "../../../Windows/DLL.h"
#include "../../../Windows/ErrorMsg.h"
#include "../../../Windows/FileFind.h"

#include "../Explorer/ContextMenuFlags.h"
#include "../Explorer/RegistryContextMenu.h"
#include "../Explorer/resource.h"

#include "../FileManager/PropertyNameRes.h"

#include "../GUI/ExtractDialogRes.h"

#include "FormatUtils.h"
#include "HelpUtils.h"
#include "LangUtils.h"
#include "MenuPage.h"
#include "MenuPageRes.h"
#include "ShellIntegrationModern.h"
#include "ShellMenuTransaction.h"
#include "../../../Common/IntToString.h"
#include "ShellOperationWait.h"

#ifdef ZIP7_DARKMODE
#include "../../../../DarkMode/lib/include/Darkmodelib.h"
#endif

using namespace NWindows;
using namespace NContextMenuFlags;

#ifdef Z7_LANG
static const UInt32 kLangIDs[] =
{
  IDX_SYSTEM_INTEGRATE_TO_MENU,
  IDX_SYSTEM_CASCADED_MENU,
  IDX_SYSTEM_ICON_IN_MENU,
  IDX_EXTRACT_ELIM_DUP,
  IDT_SYSTEM_ZONE,
  IDT_SYSTEM_CONTEXT_MENU_ITEMS
};
#endif

#define kMenuTopic "fm/options.htm#sevenZip"

struct CContextMenuItem
{
  unsigned ControlID;
  UInt32 Flag;
};

static const CContextMenuItem kMenuItems[] =
{
  { IDS_CONTEXT_OPEN, kOpen },
  { IDS_CONTEXT_OPEN, kOpenAs },
  { IDS_CONTEXT_EXTRACT, kExtract },
  { IDS_CONTEXT_EXTRACT_HERE, kExtractHere },
  { IDS_CONTEXT_EXTRACT_TO, kExtractTo },

  { IDS_CONTEXT_TEST, kTest },

  { IDS_CONTEXT_COMPRESS, kCompress },
  { IDS_CONTEXT_COMPRESS_TO, kCompressTo7z },
  { IDS_CONTEXT_COMPRESS_TO, kCompressToZip },

  #ifndef UNDER_CE
  { IDS_CONTEXT_COMPRESS_EMAIL, kCompressEmail },
  { IDS_CONTEXT_COMPRESS_TO_EMAIL, kCompressTo7zEmail },
  { IDS_CONTEXT_COMPRESS_TO_EMAIL, kCompressToZipEmail },
  #endif

  { IDS_PROP_CHECKSUM, kCRC },
  { IDS_PROP_CHECKSUM, kCRC_Cascaded },
};


#if !defined(_WIN64)
extern bool g_Is_Wow64;
#endif

#ifndef KEY_WOW64_64KEY
  #define KEY_WOW64_64KEY (0x0100)
#endif

#ifndef KEY_WOW64_32KEY
  #define KEY_WOW64_32KEY (0x0200)
#endif


static void LoadLang_Spec(UString &s, UInt32 id, const char *eng)
{
  LangString(id, s);
  if (s.IsEmpty())
    s = eng;
  s.RemoveChar(L'&');
}


/* The texts of the new mode controls. A language file may provide them under
   the same ids; the built-in fallback is Chinese (written with \u escapes so
   that this source file stays pure ASCII - MSVC reads it as codepage 936 and
   -WX turns warning C4819 into an error otherwise). */
static void Set_ModeControl_Text(HWND hwnd, unsigned id, const wchar_t *fallback)
{
  UString s;
  LangString(id, s);
  if (s.IsEmpty())
    s = fallback;
  ::SetDlgItemTextW(hwnd, id, s.Ptr());
}

static void Set_ModeControls_Text(HWND hwnd)
{
  Set_ModeControl_Text(hwnd, IDT_SYSTEM_MENU_MODE,
      L"\u53F3\u952E\u83DC\u5355\u96C6\u6210\uFF1A");   // "Context menu integration:"
  Set_ModeControl_Text(hwnd, IDX_SYSTEM_MENU_CLASSIC,
      L"\u7ECF\u5178\u83DC\u5355\uFF08\u201C\u663E\u793A\u66F4\u591A\u9009\u9879\u201D\uFF09");
  Set_ModeControl_Text(hwnd, IDX_SYSTEM_MENU_MODERN,
      L"Windows 11 \u65B0\u83DC\u5355\uFF08\u7A00\u758F\u5305\uFF09");
  Set_ModeControl_Text(hwnd, IDX_SYSTEM_MENU_BOTH,
      L"\u4E24\u8005\u90FD\u6CE8\u518C\uFF08\u6587\u4EF6\u4E0A\u4F1A\u91CD\u590D\uFF09");
  Set_ModeControl_Text(hwnd, IDX_SYSTEM_MENU_NONE,
      L"\u90FD\u4E0D\u6CE8\u518C");
}


bool CMenuPage::OnInit()
{
  _initMode = true;

  Clear_MenuChanged();
  
#ifdef Z7_LANG
  LangSetDlgItems(*this, kLangIDs, Z7_ARRAY_SIZE(kLangIDs));
#endif

  #ifdef UNDER_CE

  HideItem(IDX_SYSTEM_INTEGRATE_TO_MENU);
  HideItem(IDX_SYSTEM_INTEGRATE_TO_MENU_2);

  #else

  {
    UString s;
    {
      CWindow window(GetItem(IDX_SYSTEM_INTEGRATE_TO_MENU));
      window.GetText(s);
    }
    UString bit64 = LangString(IDS_PROP_BIT64);
    if (bit64.IsEmpty())
      bit64 = "64-bit";
    #ifdef _WIN64
      bit64.Replace(L"64", L"32");
    #endif
    s.Add_Space();
    s.Add_Char('(');
    s += bit64;
    s.Add_Char(')');
    SetItemText(IDX_SYSTEM_INTEGRATE_TO_MENU_2, s);
  }

  const FString prefix = NDLL::GetModuleDirPrefix();
  
  _dlls[0].ctrl = IDX_SYSTEM_INTEGRATE_TO_MENU;
  _dlls[1].ctrl = IDX_SYSTEM_INTEGRATE_TO_MENU_2;
  
  _dlls[0].wow = 0;
  _dlls[1].wow =
      #ifdef _WIN64
        KEY_WOW64_32KEY
      #else
        KEY_WOW64_64KEY
      #endif
      ;

  for (unsigned d = 0; d < 2; d++)
  {
    CShellDll &dll = _dlls[d];

    dll.wasChanged = false;

    #ifndef _WIN64
    if (d != 0 && !g_Is_Wow64)
    {
      HideItem(dll.ctrl);
      continue;
    }
    #endif

    FString &path = dll.Path;
    path = prefix;
    path += (d == 0 ? "RoxaZipShell.dll" :
        #ifdef _WIN64
          "RoxaZipShell32.dll"
        #else
          "RoxaZipShell64.dll"
        #endif
        );


    if (!NFile::NFind::DoesFileExist_Raw(path))
    {
      path.Empty();
      EnableItem(dll.ctrl, false);
    }
    else
    {
      dll.prevValue = CheckContextMenuHandler(fs2us(path), dll.wow);
      CheckButton(dll.ctrl, dll.prevValue);
    }
  }

  #endif


  /* measure (with everything still visible) how much room the two classic
     checkboxes take, so the controls below can be moved up when they are hidden */
  {
    _rowShift = 0;
    _currentShift = 0;
    RECT r1, r2;
    if (::GetWindowRect(GetItem(IDX_SYSTEM_INTEGRATE_TO_MENU), &r1)
        && ::GetWindowRect(GetItem(IDX_SYSTEM_CASCADED_MENU), &r2))
      _rowShift = r2.top - r1.top;
  }

  Set_ModeControls_Text(*this);
  EnableItem(IDX_SYSTEM_MENU_MODERN, NShellIntegrationModern::Is_Supported());
  EnableItem(IDX_SYSTEM_MENU_BOTH, NShellIntegrationModern::Is_Supported());
  Update_MenuMode_Controls();

  CContextMenuInfo ci;
  ci.Load();

  CheckButton(IDX_SYSTEM_CASCADED_MENU, ci.Cascaded.Val);
  CheckButton(IDX_SYSTEM_ICON_IN_MENU, ci.MenuIcons.Val);
  CheckButton(IDX_EXTRACT_ELIM_DUP, ci.ElimDup.Val);

  _listView.Attach(GetItem(IDL_SYSTEM_OPTIONS));
  _zoneCombo.Attach(GetItem(IDC_SYSTEM_ZONE));

  {
    unsigned wz = ci.WriteZone;
    if (wz == (UInt32)(Int32)-1)
      wz = 0;
    for (unsigned i = 0; i <= 3; i++)
    {
      unsigned val = i;
      UString s;
      if (i == 3)
      {
        if (wz < 3)
          break;
        val = wz;
      }
      else
      {
        #define MY_IDYES  406
        #define MY_IDNO   407
        if (i == 0)
          LoadLang_Spec(s, MY_IDNO, "No");
        else if (i == 1)
          LoadLang_Spec(s, MY_IDYES, "Yes");
        else
          LangString(IDT_ZONE_FOR_OFFICE, s);
      }
      if (s.IsEmpty())
        s.Add_UInt32(val);
      if (i == 0)
        s.Insert(0, L"* ");
      const int index = (int)_zoneCombo.AddString_SetItemData(s, (LPARAM)val);
      if (val == wz)
        _zoneCombo.SetCurSel(index);
    }
  }


  const UInt32 newFlags = LVS_EX_CHECKBOXES | LVS_EX_FULLROWSELECT;
  _listView.SetExtendedListViewStyle(newFlags, newFlags);

  _listView.InsertColumn(0, L"", 200);

  for (unsigned i = 0; i < Z7_ARRAY_SIZE(kMenuItems); i++)
  {
    const CContextMenuItem &menuItem = kMenuItems[i];

    UString s = LangString(menuItem.ControlID);
    if (menuItem.Flag == kCRC)
      s = "HASH";
    else if (menuItem.Flag == kCRC_Cascaded)
      s = "RoxaZip > HASH";
    if (menuItem.Flag == kOpenAs
        || menuItem.Flag == kCRC
        || menuItem.Flag == kCRC_Cascaded)
       s += " >";

    switch (menuItem.ControlID)
    {
      case IDS_CONTEXT_EXTRACT_TO:
      {
        s = MyFormatNew(s, LangString(IDS_CONTEXT_FOLDER));
        break;
      }
      case IDS_CONTEXT_COMPRESS_TO:
      case IDS_CONTEXT_COMPRESS_TO_EMAIL:
      {
        UString s2 = LangString(IDS_CONTEXT_ARCHIVE);
        switch (menuItem.Flag)
        {
          case kCompressTo7z:
          case kCompressTo7zEmail:
            s2 += (".7z");
            break;
          case kCompressToZip:
          case kCompressToZipEmail:
            s2 += (".zip");
            break;
        }
        s = MyFormatNew(s, s2);
        break;
      }
    }

    const int itemIndex = _listView.InsertItem(i, s);
    _listView.SetCheckState((unsigned)itemIndex, ((ci.Flags & menuItem.Flag) != 0));
  }

  _listView.SetColumnWidthAuto(0);
  _initMode = false;

#ifdef ZIP7_DARKMODE
  dmlib::setDarkListViewCheckboxes(_listView);
#endif

  return CPropertyPage::OnInit();
}


#ifndef UNDER_CE

static void ShowMenuErrorMessage(const wchar_t *m, HWND hwnd)
{
  MessageBoxW(hwnd, m, L"RoxaZip", MB_ICONERROR);
}

#endif


/* Controls below the two classic checkboxes; they move up when the checkboxes are
   hidden, so that no empty space is left in the page. */
static const unsigned k_MenuLayoutIDs[] =
{
  IDX_SYSTEM_CASCADED_MENU,
  IDX_SYSTEM_ICON_IN_MENU,
  IDX_EXTRACT_ELIM_DUP,
  IDT_SYSTEM_ZONE,
  IDC_SYSTEM_ZONE,
  IDT_SYSTEM_CONTEXT_MENU_ITEMS,
  IDL_SYSTEM_OPTIONS
};

static void Move_Control_By(HWND parent, HWND h, int dy, int extraHeight)
{
  RECT r;
  ::GetWindowRect(h, &r);
  POINT pts[2] = { { r.left, r.top }, { r.right, r.bottom } };
  ::MapWindowPoints(NULL, parent, pts, 2);

  ::SetWindowPos(h, NULL, pts[0].x, pts[0].y + dy,
      pts[1].x - pts[0].x, pts[1].y - pts[0].y + extraHeight,
      SWP_NOZORDER | SWP_NOACTIVATE);
}


CMenuPage::enum_MenuMode CMenuPage::Get_Saved_MenuMode() const
{
  bool classicFiles = false;
  #ifndef UNDER_CE
  if (!_dlls[0].Path.IsEmpty())
    classicFiles = CheckContextMenuHandler(fs2us(_dlls[0].Path), _dlls[0].wow);
  #endif

  const bool modern = NShellIntegrationModern::Is_Installed();

  if (modern)
    return classicFiles ? kMenuMode_Both : kMenuMode_Modern;
  return classicFiles ? kMenuMode_Classic : kMenuMode_None;
}


CMenuPage::enum_MenuMode CMenuPage::Get_Checked_MenuMode() const
{
  if (IsButtonCheckedBool(IDX_SYSTEM_MENU_MODERN)) return kMenuMode_Modern;
  if (IsButtonCheckedBool(IDX_SYSTEM_MENU_BOTH))   return kMenuMode_Both;
  if (IsButtonCheckedBool(IDX_SYSTEM_MENU_NONE))   return kMenuMode_None;
  return kMenuMode_Classic;
}


void CMenuPage::Set_MenuMode_Controls(enum_MenuMode mode)
{
  unsigned id = IDX_SYSTEM_MENU_CLASSIC;
  switch (mode)
  {
    case kMenuMode_Classic: id = IDX_SYSTEM_MENU_CLASSIC; break;
    case kMenuMode_Modern:  id = IDX_SYSTEM_MENU_MODERN; break;
    case kMenuMode_Both:    id = IDX_SYSTEM_MENU_BOTH; break;
    case kMenuMode_None:    id = IDX_SYSTEM_MENU_NONE; break;
  }
  ::CheckRadioButton(*this, IDX_SYSTEM_MENU_CLASSIC, IDX_SYSTEM_MENU_NONE, (int)id);

  /* The two checkboxes below control the machine-wide classic registration
     (HKEY_LOCAL_MACHINE, including the 32-bit DLL). The Windows 11 menu does not
     use it - it needs the sparse package - and an active classic registration
     next to the package would list RoxaZip twice in the classic menu, so they
     are hidden unless a mode uses the classic registration. The controls below
     move up when they are hidden, so no empty space is left. */
  const bool classic = (mode == kMenuMode_Classic || mode == kMenuMode_Both);
  ShowItem_Bool(IDX_SYSTEM_INTEGRATE_TO_MENU, classic);
  ShowItem_Bool(IDX_SYSTEM_INTEGRATE_TO_MENU_2, classic);

  const int shift = classic ? 0 : _rowShift;      // rows hidden -> move up
  const int dy = _currentShift - shift;
  if (dy != 0)
  {
    const unsigned last = Z7_ARRAY_SIZE(k_MenuLayoutIDs) - 1;
    for (unsigned i = 0; i < Z7_ARRAY_SIZE(k_MenuLayoutIDs); i++)
    {
      /* the list at the end grows, so that its bottom edge stays where it is */
      const int extra = (i == last) ? (shift - _currentShift) : 0;
      Move_Control_By(*this, GetItem(k_MenuLayoutIDs[i]), dy, extra);
    }
    _currentShift = shift;
  }
}


void CMenuPage::Update_MenuMode_Controls()
{
  Set_MenuMode_Controls(Get_Saved_MenuMode());
}


#ifndef UNDER_CE

class CMenuModeBackend
{
  CShellDll *_dlls;
  HWND _owner;
public:
  UString MsixPath;
  UString Error;

  CMenuModeBackend(CShellDll *dlls, HWND owner): _dlls(dlls), _owner(owner) {}

  unsigned ClassicMask() const
  {
    unsigned mask = 0;
    for (unsigned d = 0; d < 2; d++)
      if (!_dlls[d].Path.IsEmpty()
          && CheckContextMenuHandler_Dll(fs2us(_dlls[d].Path), _dlls[d].wow))
        mask |= 1u << d;
    return mask;
  }

  bool ClassicComplete(unsigned mask) const
  {
    for (unsigned d = 0; d < 2; d++)
      if ((mask & (1u << d)) && !CheckContextMenuHandler_Complete(
          fs2us(_dlls[d].Path), _dlls[d].wow)) return false;
    return true;
  }

  bool Set(unsigned part, unsigned value, bool restoring)
  {
    UString error;
    HRESULT hr = S_OK;
    switch (part)
    {
      case NShellMenuTransaction::kModern:
        if (NShellIntegrationModern::Is_Installed() != (value != 0))
          hr = value ? NShellIntegrationModern::Install(MsixPath,
              fs2us(NDLL::GetModuleDirPrefix()), error)
              : NShellIntegrationModern::Remove(error);
        break;
      case NShellMenuTransaction::kFolders:
        if (NShellIntegrationModern::Get_FolderRegistration_Mask() != value)
          hr = NShellIntegrationModern::Set_FolderRegistration_Mask(value, error);
        break;
      case NShellMenuTransaction::kClassic:
        if (ClassicMask() != value || (!restoring && !ClassicComplete(value)))
        {
          if (NShellIntegrationModern::Is_Process_Elevated())
            hr = HRESULT_FROM_WIN32(SetContextMenuHandler_State(value));
          else
          {
            UString args = L"-ShellMenu=state:";
            args.Add_UInt32(value);
            hr = NShellIntegrationModern::Run_Elevated_Self(args, error, _owner);
          }
        }
        break;
    }
    if (hr == S_OK)
      return true;
    if (error.IsEmpty())
      error = NError::MyFormatMessage(HRESULT_FACILITY(hr) == FACILITY_WIN32
          ? HRESULT_CODE(hr) : (DWORD)hr);
    char code[9];
    ConvertUInt32ToHex8Digits((UInt32)hr, code);
    error += L" (HRESULT 0x";
    error += code;
    error += L")";
    if (!Error.IsEmpty())
      Error.Add_LF();
    if (restoring)
      Error += L"Could not restore the previous menu: ";
    Error += error;
    return false;
  }
};

#endif


bool CMenuPage::Apply_MenuMode(enum_MenuMode mode)
{
  #ifndef UNDER_CE
  using namespace NShellMenuTransaction;
  const bool wantClassic = (mode == kMenuMode_Classic || mode == kMenuMode_Both);
  const bool wantModern = (mode == kMenuMode_Modern || mode == kMenuMode_Both);
  if (wantModern && !NShellIntegrationModern::Is_Supported())
  {
    ShowMenuErrorMessage(L"The Windows 11 menu is not supported in this build.", *this);
    return false;
  }

  CMenuModeBackend backend(_dlls, *this);
  backend.MsixPath = NShellIntegrationModern::Get_DefaultMsixPath();
  const unsigned before[kNumParts] = {
      NShellIntegrationModern::Is_Installed() ? 1u : 0u,
      NShellIntegrationModern::Get_FolderRegistration_Mask(),
      backend.ClassicMask() };
  unsigned available = 0;
  for (unsigned d = 0; d < 2; d++)
    if (!_dlls[d].Path.IsEmpty())
      available |= 1u << d;
  if (wantClassic && available == 0)
  {
    ShowMenuErrorMessage(L"The shell extension DLL was not found.", *this);
    return false;
  }

  // Check the package before touching any registration. Package removal is the
  // last operation, so a successful removal never needs a reinstall to commit.
  if (wantModern && !before[kModern])
  {
    if (backend.MsixPath.IsEmpty())
    {
      ShowMenuErrorMessage(L"Package file not found: RoxaZip.ShellExtension*.msix", *this);
      return false;
    }
  }
  unsigned changed = 0, checked = 0;
  for (unsigned d = 0; d < 2; d++)
  {
    if (_dlls[d].wasChanged) changed |= 1u << d;
    if (IsButtonCheckedBool(_dlls[d].ctrl)) checked |= 1u << d;
  }
  const unsigned classic = MergeClassicMask(before[kClassic], available,
      _menuMode_Changed, wantClassic, changed, checked);
  const unsigned after[kNumParts] = {
      wantModern ? 1u : 0u, wantModern ? 3u : 0u, classic };
  const unsigned repair = backend.ClassicComplete(classic) ? 0 : (1u << kClassic);
  if (!NShellMenuTransaction::Apply(backend, before, after, repair))
  {
    ShowMenuErrorMessage(backend.Error, *this);
    return false;
  }

  for (unsigned d = 0; d < 2; d++)
  {
    CShellDll &dll = _dlls[d];
    if (!dll.Path.IsEmpty())
    {
      dll.prevValue = CheckContextMenuHandler(fs2us(dll.Path), dll.wow);
      CheckButton(dll.ctrl, dll.prevValue);
      dll.wasChanged = false;
    }
  }
  #endif
  Update_MenuMode_Controls();
  return true;
}


LONG CMenuPage::OnApply()
{
  #ifndef UNDER_CE

  CShellOperationGuard guard(*this);
  if (_menuMode_Changed || _dlls[0].wasChanged || _dlls[1].wasChanged)
  {
    if (!Apply_MenuMode(Get_Checked_MenuMode()))
      return PSNRET_INVALID_NOCHANGEPAGE;
    _menuMode_Changed = false;
  }

  #endif

  if (_cascaded_Changed
      || _menuIcons_Changed
      || _elimDup_Changed
      || _writeZone_Changed
      || _flags_Changed)
  {
    CContextMenuInfo ci;
    ci.Cascaded.Val = IsButtonCheckedBool(IDX_SYSTEM_CASCADED_MENU);
    ci.Cascaded.Def = _cascaded_Changed;

    ci.MenuIcons.Val = IsButtonCheckedBool(IDX_SYSTEM_ICON_IN_MENU);
    ci.MenuIcons.Def = _menuIcons_Changed;
    
    ci.ElimDup.Val = IsButtonCheckedBool(IDX_EXTRACT_ELIM_DUP);
    ci.ElimDup.Def = _elimDup_Changed;

    {
      int zoneIndex = (int)_zoneCombo.GetItemData_of_CurSel();
      if (zoneIndex <= 0)
        zoneIndex = -1;
      ci.WriteZone = (UInt32)(Int32)zoneIndex;
    }

    ci.Flags = 0;
    
    for (unsigned i = 0; i < Z7_ARRAY_SIZE(kMenuItems); i++)
      if (_listView.GetCheckState(i))
        ci.Flags |= kMenuItems[i].Flag;
    
    ci.Flags_Def = _flags_Changed;
    ci.Save();

    Clear_MenuChanged();
  }

  // UnChanged();

  return PSNRET_NOERROR;
}

void CMenuPage::OnNotifyHelp()
{
  ShowHelpWindow(kMenuTopic);
}

bool CMenuPage::OnButtonClicked(unsigned buttonID, HWND buttonHWND)
{
  switch (buttonID)
  {
    #ifndef UNDER_CE
    case IDX_SYSTEM_INTEGRATE_TO_MENU:
    case IDX_SYSTEM_INTEGRATE_TO_MENU_2:
    {
      for (unsigned d = 0; d < 2; d++)
      {
        CShellDll &dll = _dlls[d];
        if (buttonID == dll.ctrl && !dll.Path.IsEmpty())
          dll.wasChanged = true;
      }
      break;
    }
    #endif

    case IDX_SYSTEM_CASCADED_MENU: _cascaded_Changed = true; break;
    case IDX_SYSTEM_ICON_IN_MENU: _menuIcons_Changed = true; break;
    case IDX_EXTRACT_ELIM_DUP: _elimDup_Changed = true; break;
    // case IDX_EXTRACT_WRITE_ZONE: _writeZone_Changed = true; break;

    case IDX_SYSTEM_MENU_CLASSIC:
    case IDX_SYSTEM_MENU_MODERN:
    case IDX_SYSTEM_MENU_BOTH:
    case IDX_SYSTEM_MENU_NONE:
      _menuMode_Changed = true;
      /* the classic checkboxes only make sense for the modes that use the classic
         registration - show or hide them right away */
      Set_MenuMode_Controls(Get_Checked_MenuMode());
      // Show the same defaults that Apply will use, preserving explicit edits.
      if (Get_Checked_MenuMode() == kMenuMode_Classic || Get_Checked_MenuMode() == kMenuMode_Both)
        for (unsigned d = 0; d < 2; d++)
          if (!_dlls[d].wasChanged && !_dlls[d].Path.IsEmpty())
            CheckButton(_dlls[d].ctrl, true);
      break;
      
    default:
      return CPropertyPage::OnButtonClicked(buttonID, buttonHWND);
  }
  
  Changed();
  return true;
}


bool CMenuPage::OnCommand(unsigned code, unsigned itemID, LPARAM param)
{
  if (code == CBN_SELCHANGE && itemID == IDC_SYSTEM_ZONE)
  {
    _writeZone_Changed = true;
    Changed();
    return true;
  }
  return CPropertyPage::OnCommand(code, itemID, param);
}


bool CMenuPage::OnNotify(UINT controlID, LPNMHDR lParam)
{
  if (lParam->hwndFrom == HWND(_listView))
  {
    switch (lParam->code)
    {
      case (LVN_ITEMCHANGED):
        return OnItemChanged((const NMLISTVIEW *)lParam);
    }
  }
  return CPropertyPage::OnNotify(controlID, lParam);
}


bool CMenuPage::OnItemChanged(const NMLISTVIEW *info)
{
  if (_initMode)
    return true;
  if ((info->uChanged & LVIF_STATE) != 0)
  {
    UINT oldState = info->uOldState & LVIS_STATEIMAGEMASK;
    UINT newState = info->uNewState & LVIS_STATEIMAGEMASK;
    if (oldState != newState)
    {
      _flags_Changed = true;
      Changed();
    }
  }
  return true;
}

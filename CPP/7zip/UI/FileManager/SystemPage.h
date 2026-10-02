// SystemPage.h
 
#ifndef ZIP7_INC_SYSTEM_PAGE_H
#define ZIP7_INC_SYSTEM_PAGE_H

#include "../../../Windows/Control/ImageList.h"
#include "../../../Windows/Control/ListView.h"
#include "../../../Windows/Control/PropertyPage.h"

#include "FilePlugins.h"
#include "RegistryAssociations.h"

enum EExtState
{
  kExtState_Clear = 0,
  kExtState_Other,
  kExtState_7Zip
};

struct CModifiedExtInfo: public NRegistryAssoc::CShellExtInfo
{
  int OldState;
  int State;
  int ImageIndex;
  bool Other;
  bool Other7Zip;

  CModifiedExtInfo(): ImageIndex(-1) {}

  CSysString GetString() const;

  void SetState(const UString &iconPath)
  {
    State = kExtState_Clear;
    Other = false;
    Other7Zip = false;
    if (!ProgramKey.IsEmpty())
    {
      State = kExtState_Other;
      Other = true;
      if (IsIt7Zip())
      {
        Other7Zip = !iconPath.IsEqualTo_NoCase(IconPath);
        if (!Other7Zip)
        {
          State = kExtState_7Zip;
          Other = false;
        }
      }
    }
    OldState = State;
  }
};

struct CAssoc
{
  CModifiedExtInfo Pair[2];
  int SevenZipImageIndex;

  /* The effective default app of Windows 10+ (UserChoice). It overrides the
     classic ProgID that this page reads and writes, and an application cannot
     change it (it is protected by a hash) - so it is shown in its own column. */
  UString SystemDefault;

  int GetIconIndex() const
  {
    for (unsigned i = 0; i < 2; i++)
    {
      const CModifiedExtInfo &pair = Pair[i];
      if (pair.State == kExtState_Clear)
        continue;
      if (pair.State == kExtState_7Zip)
        return SevenZipImageIndex;
      if (pair.ImageIndex != -1)
        return pair.ImageIndex;
    }
    return -1;
  }
};

#ifdef UNDER_CE
  #define NUM_EXT_GROUPS 1
#else
  #define NUM_EXT_GROUPS 2
#endif

struct CSystemDefaultsJob;

class CSystemPage: public NWindows::NControl::CPropertyPage
{
  CExtDatabase _extDB;
  CObjectVector<CAssoc> _items;

  unsigned _numIcons;
  NWindows::NControl::CImageList _imageList;
  NWindows::NControl::CListView _listView;

  bool _needSave;
  /* the property sheet lays the page out after OnInit(), so the buttons are
     placed above their columns a few times by a timer */
  unsigned _alignTicks;
  CSystemDefaultsJob *_defaultsJob;
  bool _defaultsLoaded;
  bool _defaultsPending;

  HKEY GetHKey(unsigned
      #if NUM_EXT_GROUPS != 1
        group
      #endif
      ) const
  {
    #if NUM_EXT_GROUPS == 1
      return HKEY_CLASSES_ROOT;
    #else
      return group == 0 ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE;
    #endif
  }

  int AddIcon(const UString &path, int iconIndex);
  unsigned GetRealIndex(unsigned listIndex) const { return listIndex; }
  void RefreshListItem(unsigned group, unsigned listIndex);
  void ChangeState(unsigned group, const CUIntVector &indices);
  void ChangeState(unsigned group);
  void UpdateSystemDefaults();
  /* places the two "+" buttons above the column they act on */
  void Position_MenuButtons();
  /* opens Windows default app settings (double click) */
  void OpenDefaultAppDialog(unsigned listIndex);
  /* deletes the UserChoice value of one row, so the classic ProgID of this
     program becomes effective again (right click menu) */
  void ResetSystemDefault(unsigned listIndex);

  bool OnListKeyDown(LPNMLVKEYDOWN keyDownInfo);
  
public:
  bool WasChanged;
  
  CSystemPage(): _needSave(false), _alignTicks(0), _defaultsJob(NULL),
      _defaultsLoaded(false), _defaultsPending(false), WasChanged(false) {}

  virtual bool OnDestroy() Z7_override;
  virtual bool OnMessage(UINT message, WPARAM wParam, LPARAM lParam) Z7_override;

  virtual bool OnInit() Z7_override;
  virtual void OnNotifyHelp() Z7_override;
  virtual bool OnNotify(UINT controlID, LPNMHDR lParam) Z7_override;
  virtual bool OnTimer(WPARAM timerID, LPARAM lParam) Z7_override;
  virtual bool OnSize(WPARAM wParam, int xSize, int ySize) Z7_override;
  virtual LONG OnSetActive() Z7_override;
  virtual LONG OnApply() Z7_override;
  virtual bool OnButtonClicked(unsigned buttonID, HWND buttonHWND) Z7_override;
};

/* Applies "-AssocAll=+ext1,ext2-ext3" to HKEY_LOCAL_MACHINE and returns 0 on
   success. Used by "RoxaZipFM.exe <spec>", which the system page starts elevated when
   the "all users" column has to be changed (one UAC prompt instead of "run 7-Zip
   as administrator"). */
int ApplyAssocAll_FromCommandLine(const wchar_t *spec);

#endif

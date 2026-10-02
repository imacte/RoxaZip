// MenuPage.h
 
#ifndef ZIP7_INC_MENU_PAGE_H
#define ZIP7_INC_MENU_PAGE_H

#include "../../../Windows/Control/PropertyPage.h"
#include "../../../Windows/Control/ComboBox.h"
#include "../../../Windows/Control/ListView.h"

struct CShellDll
{
  FString Path;
  bool wasChanged;
  bool prevValue;
  unsigned ctrl;
  UInt32 wow;

  CShellDll(): wasChanged (false), prevValue(false), ctrl(0), wow(0) {}
};

class CMenuPage: public NWindows::NControl::CPropertyPage
{
  bool _initMode;

  bool _cascaded_Changed;
  bool _menuIcons_Changed;
  bool _elimDup_Changed;
  bool _writeZone_Changed;
  bool _flags_Changed;
  bool _menuMode_Changed;
  /* height of the two classic checkboxes (in pixels) and how far the controls
     below are moved up at the moment */
  int _rowShift;
  int _currentShift;

  void Clear_MenuChanged()
  {
    _cascaded_Changed = false;
    _menuIcons_Changed = false;
    _elimDup_Changed = false;
    _writeZone_Changed = false;
    _flags_Changed = false;
    _menuMode_Changed = false;
  }

public:
  /* Which context menu(s) RoxaZip is registered in:
       Classic - machine-wide classic registration (*, Folder, Directory)
       Modern  - sparse package for the Windows 11 menu + per-user classic
                 registration for Folder/Directory
       Both    - both of them (RoxaZip appears twice for files)
       None    - nowhere */
  enum enum_MenuMode
  {
    kMenuMode_Classic,
    kMenuMode_Modern,
    kMenuMode_Both,
    kMenuMode_None
  };

private:
  enum_MenuMode Get_Saved_MenuMode() const;
  enum_MenuMode Get_Checked_MenuMode() const;
  void Set_MenuMode_Controls(enum_MenuMode mode);
  void Update_MenuMode_Controls();
  bool Apply_MenuMode(enum_MenuMode mode);

  #ifndef UNDER_CE
  CShellDll _dlls[2];
  #endif
  
  NWindows::NControl::CListView _listView;
  NWindows::NControl::CComboBox _zoneCombo;

  virtual bool OnInit() Z7_override;
  virtual void OnNotifyHelp() Z7_override;
  virtual bool OnNotify(UINT controlID, LPNMHDR lParam) Z7_override;
  virtual LONG OnApply() Z7_override;
  virtual bool OnButtonClicked(unsigned buttonID, HWND buttonHWND) Z7_override;
  virtual bool OnCommand(unsigned code, unsigned itemID, LPARAM param) Z7_override;

  bool OnItemChanged(const NMLISTVIEW* info);
};

#endif

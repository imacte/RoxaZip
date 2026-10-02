// RegistryContextMenu.h

#ifndef ZIP7_INC_REGISTRY_CONTEXT_MENU_H
#define ZIP7_INC_REGISTRY_CONTEXT_MENU_H

#ifndef UNDER_CE

bool CheckContextMenuHandler_Dll(const UString &path, UInt32 wow = 0);
bool CheckContextMenuHandler_Complete(const UString &path, UInt32 wow = 0);
bool CheckContextMenuHandler(const UString &path, UInt32 wow = 0);
LONG SetContextMenuHandler(bool setMode, const UString &path, UInt32 wow = 0);

/* Registers (or unregisters) the shell extension for both DLLs next to the
   program - RoxaZipShell.dll and the 32-bit one, if it is present.

   Used by "RoxaZipFM.exe -ShellMenu=register|unregister", which the options page
   starts elevated when the machine-wide keys have to be changed: RoxaZipFM.exe then
   does not have to be restarted as administrator, the user just gets the UAC
   prompt. */
LONG SetContextMenuHandler_All(bool setMode);
LONG SetContextMenuHandler_State(unsigned mask);

#endif

#endif

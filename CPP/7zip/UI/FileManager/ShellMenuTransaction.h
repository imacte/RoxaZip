/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: GNU LGPL v2.1-or-later - see COPYING
 */
// ShellMenuTransaction.h

#ifndef ZIP7_INC_SHELL_MENU_TRANSACTION_H
#define ZIP7_INC_SHELL_MENU_TRANSACTION_H

namespace NShellMenuTransaction {

enum EPart { kModern, kFolders, kClassic, kNumParts };

// A mode supplies defaults; explicitly edited checkboxes override those defaults.
inline unsigned MergeClassicMask(unsigned before, unsigned available,
    bool modeChanged, bool wantClassic, unsigned changed, unsigned checked)
{
  if (!wantClassic) return 0;
  const unsigned defaults = modeChanged ? available : before;
  return ((defaults & ~changed) | (checked & changed)) & available;
}

// Install the replacement before removing the existing menu. Set() can fail
// after a partial write, so restore the failed operation as well as earlier ones.
// The backend reports both the original failure and any rollback failures.
template <class T>
bool Apply(T &backend, const unsigned *before, const unsigned *after, unsigned repair = 0)
{
  const EPart order[kNumParts] = {
      after[kModern] ? kModern : kFolders,
      after[kModern] ? kFolders : kClassic,
      after[kModern] ? kClassic : kModern };
  for (unsigned i = 0; i < kNumParts; i++)
  {
    const unsigned part = order[i];
    if (before[part] == after[part] && !(repair & (1u << part)))
      continue;
    if (backend.Set(part, after[part], false))
      continue;
    for (unsigned j = i + 1; j != 0;)
    {
      const unsigned restorePart = order[--j];
      if (before[restorePart] != after[restorePart])
        backend.Set(restorePart, before[restorePart], true);
    }
    return false;
  }
  return true;
}

}

#endif

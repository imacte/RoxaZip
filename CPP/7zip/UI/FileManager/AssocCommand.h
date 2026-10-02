/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: GNU LGPL v2.1-or-later - see COPYING
 */
// AssocCommand.h
#ifndef ZIP7_INC_ASSOC_COMMAND_H
#define ZIP7_INC_ASSOC_COMMAND_H

// Parse the complete argument before the caller performs any registry writes.
// The visitor validates each extension against the application's extension DB.
template<class T>
bool ParseAssocCommand(const wchar_t *spec, T &visitor)
{
  const wchar_t prefix[] = L"-AssocAll=";
  if (!spec) return false;
  for (unsigned i = 0; prefix[i]; i++)
    if (*spec++ != prefix[i]) return false;
  if (*spec != L'+' && *spec != L'-') return false;
  bool add = *spec++ == L'+';
  for (;;)
  {
    const wchar_t *start = spec;
    while ((*spec >= L'a' && *spec <= L'z') || (*spec >= L'A' && *spec <= L'Z')
        || (*spec >= L'0' && *spec <= L'9') || *spec == L'.') spec++;
    if (spec == start || *start == L'.' || spec[-1] == L'.'
        || !visitor(start, (unsigned)(spec - start), add)) return false;
    if (*spec == 0) return true;
    if (*spec == L'+' || *spec == L'-') add = *spec == L'+';
    else if (*spec != L',') return false;
    spec++;
  }
}
#endif

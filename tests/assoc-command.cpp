/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
#include <cassert>
#include <cwchar>
#include <cstdio>
#include "../CPP/7zip/UI/FileManager/AssocCommand.h"
struct Visitor
{
  unsigned Count;
  bool LastAdd;
  Visitor(): Count(0), LastAdd(false) {}
  bool operator()(const wchar_t *s, unsigned n, bool add)
  {
    Count++; LastAdd = add;
    return (n == 2 && wcsncmp(s, L"7z", n) == 0)
        || (n == 3 && wcsncmp(s, L"zip", n) == 0);
  }
};
int main()
{
  const wchar_t *bad[] = { 0, L"", L"-AssocAll=", L"-AssocAll=zip",
    L"-AssocAll=+", L"-AssocAll=+zip,", L"-AssocAll=+zip,,7z",
    L"-AssocAll=++zip", L"-AssocAll=+zip/evil", L"-AssocAll=-zip\\evil",
    L"-AssocAll=+zip-", L"-AssocAll=+zip,.7z", L"-AssocAll=+zip,unknown",
    L"-AssocAll=+zip,7z.", L"-AssocAll=+zip -7z", L"-AssocAll=+zip:7z",
    L"-AssocAll=+zip;7z", L"backup-AssocAll=+zip" };
  for (unsigned i = 0; i < sizeof(bad)/sizeof(bad[0]); i++)
  { Visitor v; assert(!ParseAssocCommand(bad[i], v)); }
  Visitor v;
  assert(ParseAssocCommand(L"-AssocAll=+zip,7z-zip+7z", v));
  assert(v.Count == 4 && v.LastAdd);
  puts("PASS: association command grammar and full-input validation");
}

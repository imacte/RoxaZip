/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
#include "../CPP/7zip/UI/FileManager/StdAfx.h"
#include <cassert>
#include <cstdio>
#include "../CPP/7zip/UI/FileManager/ShellOperationWait.h"
static unsigned ticks, closes, commands;
static LRESULT CALLBACK Proc(HWND h, UINT m, WPARAM w, LPARAM l)
{
  if (m == WM_TIMER) { ticks++; return 0; }
  if (m == WM_CLOSE) { closes++; return 0; }
  if (m == WM_COMMAND) { commands++; return 0; }
  return DefWindowProc(h, m, w, l);
}
static DWORD WINAPI Worker(void *p) { Sleep(200); SetEvent((HANDLE)p); return 0; }
int main()
{
  WNDCLASSW wc = {};
  wc.lpfnWndProc = Proc; wc.hInstance = GetModuleHandle(NULL); wc.lpszClassName = L"ShellWaitTest";
  assert(RegisterClassW(&wc));
  HWND h = CreateWindowW(wc.lpszClassName, L"", WS_OVERLAPPED, 0,0,0,0, NULL,NULL,wc.hInstance,NULL);
  assert(h);
  HANDLE event = CreateEvent(NULL, TRUE, FALSE, NULL);
  HANDLE worker = CreateThread(NULL, 0, Worker, event, 0, NULL);
  assert(event && worker);
  SetTimer(h, 1, 10, NULL);
  {
    CShellOperationGuard guard(h);
    assert(!IsWindowEnabled(h));
    PostMessage(h, WM_CLOSE, 0, 0);
    PostMessage(h, WM_COMMAND, IDOK, 0);
    PostQuitMessage(17);
    assert(WaitForShellOperation(event) == WAIT_OBJECT_0);
    assert(ticks > 0 && closes == 0 && commands == 0 && IsWindow(h));
    MSG msg;
    assert(PeekMessage(&msg, NULL, WM_QUIT, WM_QUIT, PM_REMOVE));
    assert(msg.wParam == 17);
  }
  assert(IsWindowEnabled(h));
  SendMessage(h, WM_COMMAND, IDOK, 0);
  assert(commands == 1);
  KillTimer(h, 1); DestroyWindow(h);
  WaitForSingleObject(worker, INFINITE); CloseHandle(worker); CloseHandle(event);
  puts("PASS: responsive wait, close/apply reentry guard, WM_QUIT preservation");
}

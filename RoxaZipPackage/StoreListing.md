# RoxaZip - Microsoft Store listing

<!-- RoxaZip - Copyright (c) 2026 RoxaZip contributors - License: MIT, see DOC/License-MIT.txt -->

Text for the submission form in Partner Center. The product is created and the
name is reserved; the identity values are in `Package.appxmanifest`.

Fill in both languages (the Store shows the ones matching the customer's
language, falling back to the default).

## Product name

`RoxaZip`

## Short description (en-US)

Archive manager for Windows: 7-Zip formats plus Zstandard, LZ4, LZ5, Brotli and
Fast LZMA2. No ads, no telemetry, no network access.

## Short description (zh-CN)

Windows 压缩包管理器：7-Zip 全格式，外加 Zstandard、LZ4、LZ5、Brotli、Fast LZMA2。
无广告、无遥测、不联网。

## Full description (en-US)

RoxaZip is an archive manager for Windows, based on 7-Zip and the 7-Zip ZS fork.

It reads and writes 7z, zip, tar, xz, gzip, bzip2, wim and more, and adds the
modern compressors Zstandard, LZ4, LZ5, Brotli, Lizard and Fast LZMA2. Archives
can be encrypted with AES-256, XChaCha20, AEGIS-256 or Ascon, including
encrypted file names. Built-in checksums cover SHA-256, BLAKE3 and XXH64.

The file manager integrates with Windows 11: the context menu entry is available
in the new menu (and in "Show more options" on earlier Windows versions), the
program understands the usual 7-Zip command names, and the dark theme follows
the system setting.

Everything runs locally. RoxaZip contains no advertising, no telemetry and makes
no network connections.

Features
- 7z, zip, gzip, bzip2, tar, xz, wim, iso, cab, rar (extract), vhd, dmg and more
- Zstandard, LZ4, LZ5, Brotli, Lizard and Fast LZMA2, with tuning levels
- AES-256, XChaCha20, XChaCha20-Poly1305, AEGIS-256, Ascon, cascades
- encrypted headers (`-mhe=on`), password-protected archives
- SHA-256, BLAKE3, XXH64 checksums
- Windows 11 context menu, file associations, drag and drop
- dark mode, 90+ languages
- console version for scripts (`RoxaZip`, plus the 7-Zip command names)

RoxaZip is free software under the GNU LGPL v2.1-or-later. The source code is at
https://github.com/imacte/RoxaZip - the archived formats, the codecs and the
upstream authors keep their own licenses, see COPYING in the package.

## Full description (zh-CN)

RoxaZip 是一款 Windows 压缩包管理器，基于 7-Zip 与 7-Zip ZS 分支。

支持 7z、zip、tar、xz、gzip、bzip2、wim 等格式，并加入现代压缩算法
Zstandard、LZ4、LZ5、Brotli、Lizard、Fast LZMA2。可使用 AES-256、XChaCha20、
AEGIS-256、Ascon 加密（含加密文件名）；内置 SHA-256、BLAKE3、XXH64 校验。

文件管理器与 Windows 11 集成：右键菜单出现在新菜单中（较早的 Windows 上在
"显示更多选项"里），兼容 7-Zip 的命令名，深色主题跟随系统。

所有功能都在本机运行：无广告、无遥测、不联网。

功能
- 7z、zip、gzip、bzip2、tar、xz、wim、iso、cab、rar（解压）、vhd、dmg 等
- Zstandard、LZ4、LZ5、Brotli、Lizard、Fast LZMA2，可调压缩等级
- AES-256、XChaCha20、XChaCha20-Poly1305、AEGIS-256、Ascon 及级联加密
- 加密文件名（`-mhe=on`）、口令保护
- SHA-256、BLAKE3、XXH64 校验
- Windows 11 右键菜单、文件关联、拖放
- 深色模式、90 多种语言
- 命令行版本（`RoxaZip`，同时兼容 7-Zip 命令名）

RoxaZip 是 GNU LGPL v2.1-or-later 自由软件，源码见
https://github.com/imacte/RoxaZip ；各压缩格式与编解码库保留其自身许可，
详见包内 COPYING。

## Search keywords (max 7)

`7zip`, `zip`, `unzip`, `zstandard`, `7z`, `archiver`, `compression`

## Category

Utilities > File managers

## System requirements

* Windows 10 version 2004 (build 19041) or newer, Windows 11
* x64 or ARM64
* about 30 MB of disk space

## Screenshots

`make-screenshots.ps1` captures the ones that come from the program itself into
`RoxaZipPackage\Screenshots` (1600x1000, dark theme):

| file | content |
|---|---|
| `01-file-manager.png` | the file manager with an archive open |
| `02-options-roxazip.png` | `Options > RoxaZip`, the context menu integration page |
| `03-add-to-archive.png` | the "Add to archive" dialog (AES-256 visible) |
| `04-encryption.png` | the same dialog with a password and AES-256 |
| `06-hash-blake3.png` | the BLAKE3 checksum dialog |

Still manual: `05-context-menu.png` - the Windows 11 context menu entry, because
it needs a real right-click.

```powershell
pwsh -File RoxaZipPackage\make-screenshots.ps1 -ExeDir "<installation folder>"
```

## Restricted capabilities (submission options)

Partner Center asks for a separate justification per restricted capability
("Submission options" -> restricted capabilities). The package declares exactly
one: **`runFullTrust`** (text below). `unvirtualizedResources` was requested in
the first submission and denied, so it is no longer in the manifest - there is
only one box to fill now.

### Why do you need the runFullTrust capability?

Partner Center cuts this box at **500 characters**, and it cuts silently: the
706-character version used for the first submission lost its closing argument in
the middle of the sentence. The text below is 479 characters, so paste it as one
paragraph and check the last word ("start.") is still there. The longer version
(which also named the codec DLLs and the registry) is in the git history; the
extra detail did not add anything to the argument.

```
RoxaZip is a Win32 desktop archive manager (a 7-Zip fork) shipped as MSIX. The file manager, command line tool, GUI helper and Explorer shell extension (RoxaZipShell.dll) are classic Win32 binaries, and the shell extension is a packaged COM server. They need APIs an app container lacks: CreateProcess, the Explorer context menu interfaces, common dialogs and direct file access to user-chosen archives. runFullTrust is the supported entry point; without it the app cannot start.
```

### unvirtualizedResources - no longer requested

The first submission (2026-10-02) also asked for this capability, with
`desktop6:FileSystemWriteVirtualization` set to `disabled` (that property
requires it). Certification answered on 2026-10-06 under **10.6.3 Capabilities**:

> Your request to use unvirtualizedResources has been reviewed and was denied
> based on the information provided. You may want to remove the restricted
> capability and resubmit.

Both the capability and the property were removed from `Package.appxmanifest`
for the resubmission, so there is nothing to justify here any more. Nothing is
lost by that: MSIX virtualizes writes only to `HKCU\Software` and to
`%USERPROFILE%\AppData`. Packing, extracting and editing archives in every other
location - other drives, network shares, removable media, the rest of the user
profile - still writes the real file system, exactly like the classic
installation. What changes is that the settings under `HKCU\Software\RoxaZip`
now live in the package's private hive: they are invisible to other programs and
are removed when the package is uninstalled.

Do not add it back without a justification Microsoft accepts. The
[documentation](https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-desktop6-filesystemwritevirtualization)
says the write virtualization property "is currently intended to be used only by
certain types of desktop PC games that are published by Microsoft and our
partners", and it needs the same restricted capability. If a later version really
does need unvirtualized access, name the concrete case in the submission options:
which process *outside* the package has to see which file or registry entry, and
what breaks in a package-private hive. "It is an archive manager" was not enough.

### Certification notes (optional, speeds up the review)

```
How to test RoxaZip - no account, no network, no special hardware needed:

- Windows 11: right-click any file or folder. The new context menu lists
  "RoxaZip" with a cascaded submenu (open archive, extract, extract here, test,
  add to archive, compress and send by e-mail, hash).
- "Show more options" (classic menu) shows the same entry through the shell
  extension DLL.
- Start menu: "RoxaZip" opens the file manager; "RoxaZip Console" opens a console
  window where "RoxaZip.exe i" lists the loaded codecs. Try
  "RoxaZip.exe a test.7z <some file> -m0=zstd" and "RoxaZip.exe x test.7z -oout".
- The application never connects to the network and collects no data.
```

## Start menu entries and the HeadlessAppBypass waiver

The package declares three applications, so the Start menu shows three entries:
`RoxaZip` (file manager), `RoxaZip Console` (command line, provides the `7z.exe`
alias) and `RoxaZip GUI` (progress window, provides the `7zG.exe` alias).

Hiding the two helper entries needs `AppListEntry="none"`, and the Store rejects
that with "the package specifies a headless app; you do not have permission to
create headless apps - also ensure you have the waiver HeadlessAppBypass
associated to this app". The waiver is granted per product by the Store team.

This stopped being a nice-to-have: certification of 2026-10-07 passed with the
required fix **10.1.1.11 On Device Tiles** - "the additional installed components
that are visible in the Start Menu have a unique name that clearly identifies
which item is the main product" - and the report shows all three entries with the
same icon. The waiver plus `-HideHelperApps` is the fix for the next submission;
the naming fallback is in `DOC/StoreSubmission.md`.

### How to request it

Ticket **2610020010001019** was submitted on 2026-10-02 through the "Create
support case (MSA)" link on <https://developer.microsoft.com/en-us/windows/support/>
(program Windows Developer Center, problem type App Management, support plan
Professional No Charge) and is waiting for the Store team. The form is reachable
without a business tenant; the Engage Center link for Entra ID accounts only shows
"no access" for an individual developer account, and `partnerops@microsoft.com`
went unanswered for other developers.

The steps below are the ones that worked:

Open <https://developer.microsoft.com/en-us/windows/support> and use **Create
support case (MSA)** under "Non-technical support (Dev Center programs)" - the
Entra ID link answers "no access" for an individual developer account. The old
Services Hub form
(`support.serviceshub.microsoft.com/supportforbusiness/create?sapId=...`)
redirects to the same place today: cases are managed in **Engage Center**
(<https://engagecenter.microsoft.com> -> "Support requests"). Choose the category
**Developer, Student and Startup Programs -> Dev Center -> Account Management**
(recommended by Microsoft support in
[this Q&A](https://learn.microsoft.com/en-ie/answers/questions/2115779/headlessappbypass-waiver)).
Do not rely on `partnerops@microsoft.com`, and the "Windows Developer Support"
page does not offer that category - developers got stuck in a loop there.

### How to follow up on the ticket

The case lives in Engage Center under **Support requests** (sign in with the same
MSA that created it; the official description is
<https://learn.microsoft.com/zh-cn/services-hub/microsoft-engage-center/support/support-requests>).
Open the case - its title contains the number 2610020010001019 - and reply on the
**Communication** tab. Replying to the confirmation e-mail does the same thing, as
long as the subject with the case number is kept. The list only shows requests
assigned to your workspace, so if the case does not show up (or it was closed),
create a new one through the same page and paste the follow-up text below.

Ticket text:

```
Product : RoxaZip
Store ID: 9P836WXHPJGZ
Identity: imacte.RoxaZip
Publisher: CN=99CE4C4C-7CDF-4CB7-A3F5-AAB5567A3092
Package family name: imacte.RoxaZip_dy69qcvur1ke

Please associate the "HeadlessAppBypass" waiver with this product.

RoxaZip is a Win32 archive manager packaged as MSIX. The package contains three
applications: RoxaZipFM.exe (the file manager, listed as "RoxaZip"), RoxaZip.exe
(the command line tool, needed for the 7z.exe execution alias) and RoxaZipG.exe
(the progress dialog helper that the file manager starts for long operations).
The last two are helper executables without their own user interface: they are
started by the file manager and by scripts, and listing them in the Start menu
would be confusing for customers. We therefore mark them with
AppListEntry="none", which currently blocks the package upload.
```

Follow-up for the same ticket, sent on 2026-10-07 once the product was live:

```
Follow-up for product RoxaZip (Store ID 9P836WXHPJGZ).

The product is published (version 26.3.23.0). Certification passed with one
required fix, policy 10.1.1.11 On Device Tiles: "Your submission installs
multiple components to the device. Please make sure the additional installed
components that are visible in the Start Menu have a unique name that clearly
identifies which item is the main product."

The three visible entries come from the three <Application> elements of the
package: RoxaZip (the file manager), RoxaZip Console (RoxaZip.exe, needed for the
7z.exe execution alias) and RoxaZip GUI (RoxaZipG.exe, the progress dialog helper
that the file manager starts). The two helpers have no user interface of their
own. Marking them with AppListEntry="none" is the documented way to ship helper
executables, and the upload is rejected without the HeadlessAppBypass waiver.

Please associate the HeadlessAppBypass waiver with this product so the next
submission can hide the two helper entries.
```

### After the waiver is granted

```powershell
pwsh -File RoxaZipPackage\build-store-package.ps1 -HideHelperApps
```

adds `AppListEntry="none"` to the two helper applications. For CI, add the same
switch to the "Build the Store packages" step in `.github/workflows/build.yml`.
Until the waiver exists, the packages ship with the three visible entries, which
also keeps the `7z.exe` and `7zG.exe` aliases working.

## Age rating questionnaire (expected answers)

Utility without user generated content or communication: no violence, no sex,
no language, no gambling, no user interaction, no location, no personal data.
"In-app purchases": none. "Ads": none.

## Privacy policy

RoxaZip does not collect, store or transmit personal data. It does not connect to
the network; archives are processed locally only. The application writes its
settings to `HKCU\Software\RoxaZip`.

The policy is published as [PRIVACY.md](../PRIVACY.md) in the repository, which
is the link to use in the submission form.

## Support and legal

| Field | Value |
|---|---|
| Support URL | https://github.com/imacte/RoxaZip/issues |
| Website | https://github.com/imacte/RoxaZip |
| Copyright | Copyright (c) 2026 RoxaZip contributors; based on 7-Zip by Igor Pavlov and 7-Zip ZS by Tino Reichardt and contributors |
| License | GNU LGPL v2.1-or-later (see COPYING); bundled libraries under their own licenses |
| Source code | https://github.com/imacte/RoxaZip |
| Pricing | free |

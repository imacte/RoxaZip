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

## Screenshots to capture (1366x768 or larger, 1-10 images)

1. file manager with an archive open (two panels, dark theme)
2. Options > RoxaZip - context menu integration page
3. add-to-archive dialog with `zstd` and a level
4. encryption dialog (AES-256 / XChaCha20)
5. the RoxaZip entry in the Windows 11 context menu
6. hash dialog with BLAKE3

## Age rating questionnaire (expected answers)

Utility without user generated content or communication: no violence, no sex,
no language, no gambling, no user interaction, no location, no personal data.
"In-app purchases": none. "Ads": none.

## Privacy policy

RoxaZip does not collect, store or transmit personal data. It does not connect to
the network; archives are processed locally only. The application writes its
settings to `HKCU\Software\RoxaZip` and its history to the user profile.

(For the Store form a short statement or a link is enough; the text above can be
published as `PRIVACY.md` in the repository and linked.)

## Support and legal

| Field | Value |
|---|---|
| Support URL | https://github.com/imacte/RoxaZip/issues |
| Website | https://github.com/imacte/RoxaZip |
| Copyright | Copyright (c) 2026 RoxaZip contributors; based on 7-Zip by Igor Pavlov and 7-Zip ZS by Tino Reichardt and contributors |
| License | GNU LGPL v2.1-or-later (see COPYING); bundled libraries under their own licenses |
| Source code | https://github.com/imacte/RoxaZip |
| Pricing | free |

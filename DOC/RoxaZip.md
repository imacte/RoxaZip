<!-- RoxaZip - Copyright (c) 2026 RoxaZip contributors - License: MIT, see DOC/License-MIT.txt -->
# RoxaZip

RoxaZip is based on 7-Zip and the 7-Zip ZS fork. The upstream authors,
copyright notices, licenses, archive formats and codec credits are retained.

Source: https://github.com/imacte/RoxaZip

Downloads: https://github.com/imacte/RoxaZip/releases

## Packages

- `RoxaZip-26.03-windows-<arch>.exe`: Windows installer (x64, x86, ARM64).
  The `-ndm` suffix identifies builds without dark mode.
- `RoxaZip-26.03-linux-<arch>-<compiler>.tar.gz`: Linux x64/ARM64 builds,
  compiled with GCC or Clang; executable permissions are preserved.
- `RoxaZip-26.03-codecs-<arch>.7z`: codec plugins.
- `RoxaZip-26.03-totalcmd.7z`: Total Commander plugins.
- `SHA256SUMS.txt`: checksums for all 17 packages.

Master pushes publish a prerelease after all Windows/Linux builds and tests
pass. Tags beginning with `v` publish stable releases.

## Compatibility with existing installations

Fresh installations default to a `RoxaZip` directory and create RoxaZip Start
menu shortcuts. Upgrades reuse the registered installation directory, including
existing `7-Zip-Zstandard` paths. RoxaZip replaces this fork's previous
installation; it is not a separate side-by-side installation of that fork.

### File names

Since the RoxaZip rename the shipped binaries carry RoxaZip file names:

| Previous | RoxaZip |
|---|---|
| `7z.exe` | `RoxaZip.exe` |
| `7zFM.exe` | `RoxaZipFM.exe` |
| `7zG.exe` | `RoxaZipG.exe` |
| `7za.exe` / `7zz.exe` / `7zr.exe` | `RoxaZipA.exe` / `RoxaZipZ.exe` / `RoxaZipR.exe` |
| `7z.dll` | `RoxaZip.dll` |
| `7-zip.dll` / `7-zip32.dll` | `RoxaZipShell.dll` / `RoxaZipShell32.dll` |
| `7z.sfx` / `7zCon.sfx` | `RoxaZip.sfx` / `RoxaZipCon.sfx` |
| `7z.so` (Linux) | `RoxaZip.so` |

The Linux builds map the same way but drop the `.exe` suffix: `RoxaZip`,
`RoxaZipA`, `RoxaZipR`, `RoxaZipZ` and `RoxaZip.so`.

**The old command names are not installed.** RoxaZip installs only the RoxaZip
names, so the installation directory stays free of `7z.exe`, `7zFM.exe` and
`7zG.exe`. An in-place upgrade removes the files that earlier builds of this fork
created there.

Scripts, shortcuts and scheduled tasks that call `7z`, `7zFM` or `7zG` have to
use `RoxaZip`, `RoxaZipFM` and `RoxaZipG` instead, or re-create the old names -
one command per file, from an elevated prompt:

```
mklink /H "%ProgramFiles%\RoxaZip\7z.exe"   "%ProgramFiles%\RoxaZip\RoxaZip.exe"
mklink /H "%ProgramFiles%\RoxaZip\7zFM.exe" "%ProgramFiles%\RoxaZip\RoxaZipFM.exe"
mklink /H "%ProgramFiles%\RoxaZip\7zG.exe"  "%ProgramFiles%\RoxaZip\RoxaZipG.exe"
```

A hard link shares the program with the RoxaZip file and needs no extra disk
space; a copy works as well. Note that other 7-Zip installations on the same
machine may already provide these names.

The installer also removes the `App Paths\7zFM.exe` entry that earlier builds
created.

### Registry keys, CLSID and help file

| Item | Previous | RoxaZip |
|---|---|---|
| settings, history and install path | `HKCU` / `HKLM\Software\7-Zip-Zstandard` | `Software\RoxaZip` |
| classic shell handler keys | `...\shellex\ContextMenuHandlers\7-Zip-Zstandard` | `...\RoxaZip` |
| shell extension CLSID | `{23170F69-20BB-278A-1000-000100020000}` | `{3878DDB7-37F6-4265-BB4F-835DC2A790ED}` |
| sparse package identity | `SevenZipZS.ShellExtension` | `RoxaZip.ShellExtension` |
| bundled help file | `7-zip.chm` | `RoxaZip.chm` |

Settings are **not** migrated: RoxaZip starts with a fresh settings
key, so the language, the history and the panel/view options have to be set once
after upgrading. The old `Software\7-Zip-Zstandard` key stays behind as dead data
and can be deleted.

An in-place upgrade also leaves the previous classic shell extension
registration behind (it points to the old CLSID and the old DLL). Remove it, so
Explorer lists the entry only once:

```
pwsh -File Package\disable-legacy-shell-ext.ps1
```

Values that contain a program path have to be written again after the upgrade:

- `Options -> System` in the file manager, or `RoxaZipFM.exe -AssocAll=+7z,zip`,
  re-applies the file associations;
- `Options -> RoxaZip` re-registers the sparse package of the Windows 11 context
  menu.

### The Windows 11 context menu needs the sparse package

Windows 11 shows entries in the new context menu only for *packaged* apps, so
that menu needs a package - either the sparse package `RoxaZip.ShellExtension`
(see above) or the package of the Microsoft Store variant (see
`RoxaZipPackage/`). A released installation does **not** contain the sparse
package: it has to be signed, and it is built next to the sources with

```
pwsh -File Package\build-shell-package.ps1 -InstallDir "<installation folder>"
```

which needs the Windows SDK (`makeappx`, `signtool`) and creates a self-signed
development certificate on first use (one UAC prompt for the machine-wide trust).
It copies the resulting `.msix` next to the binaries, which is where
`Options -> RoxaZip` looks for it.

Without that file the "Windows 11 menu" options are disabled and the classic
menu ("Show more options") is used - it works out of the box and needs no
package.

**Installed from the Microsoft Store?** Then the package itself provides the
menu, the file associations and the command names (`7z.exe`, `7zFM.exe`,
`7zG.exe`, managed by Windows in `%LOCALAPPDATA%\Microsoft\WindowsApps`). The
program detects that and disables the classic registration options of the
options page; the sparse package must not be registered on top of it, because
both would claim the same shell extension CLSID.

For a release that should offer the Windows 11 menu without an extra step, the
package has to be signed with a real code signing certificate whose subject
matches `Identity/@Publisher` in `Package/AppxManifest.xml` and shipped next to
the binaries - or distributed through the Microsoft Store, which signs the
uploaded package itself (`RoxaZipPackage/`).

### Kept on purpose

- **Source tree and upstream assets** keep their upstream names: `CPP/7zip`,
  `7zip.mak`, `7zip_gcc.mak`, `C/Util/7zipInstall`, `C/Util/7zipUninstall` and
  the plugin interface GUIDs `k_7zip_GUID_*`. Only the shipped product and the
  identifiers that users, scripts or the shell see carry the RoxaZip name; see
  [UpstreamSynchronization.md](UpstreamSynchronization.md).
- **Plugin and interface GUIDs**: the values behind `k_7zip_GUID_*` are still
  7-Zip's (`23170F69-…`), so codec, hash and format plugins keep working. Only
  the shell extension has a new CLSID.
- **File association ProgIDs** keep the legacy `7-Zip-Zstandard.<ext>` prefix;
  only the values that contain the program path are re-written.
- **Total Commander plugin** (`tc7z.dll`, `tc7z64.dll`): Total Commander loads
  the plugin by exactly these file names.

Upstream language files keep their `7-Zip` signature. Visible translated product
names are adapted when loaded. The bundled upstream help and license documents
continue to credit 7-Zip and its authors.

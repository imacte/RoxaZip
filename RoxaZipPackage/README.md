# RoxaZip Store package

<!-- RoxaZip - Copyright (c) 2026 RoxaZip contributors - License: MIT, see DOC/License-MIT.txt -->

Builds the **full MSIX package** for the Microsoft Store.

Do not confuse the three package flavours of this repository:

| | what it is | who builds it |
|---|---|---|
| Windows setup (`RoxaZip-<ver>-windows-<arch>.exe`) | classic installation, appended to the upstream SFX installer | `do-release.cmd` in CI |
| `Package/` (sparse package) | gives an **existing classic installation** a package identity for the Windows 11 menu; stays optional | `Package/build-shell-package.ps1`, locally |
| `RoxaZipPackage/` (this folder) | **full** package for the Store, contains the whole program | `build-store-package.ps1`, locally or in CI |

## What the Store package adds

* the **Windows 11 context menu** entry (`windows.fileExplorerContextMenus` plus
  the `com:SurrogateServer` for `RoxaZipShell.dll`) - this is the only way to get
  it, because Windows 11 shows the new menu for packaged apps only;
* the **legacy command names** `7z.exe`, `7zFM.exe`, `7zG.exe` as
  `AppExecutionAlias` entries - Windows creates them in
  `%LOCALAPPDATA%\Microsoft\WindowsApps`, so no `7z*.exe` files end up in the
  installation folder;
* **file associations** from the manifest;
* updates and uninstall through the Store.

### Never installed together with the sparse package

The Store package and the sparse package of `Package/build-shell-package.ps1`
both register the shell extension CLSID
`{3878DDB7-37F6-4265-BB4F-835DC2A790ED}` for the same user. Windows then holds
two registrations of the same CLSID and it is undefined which one the menu uses,
so remove the sparse registration before installing this package:

```powershell
Get-AppxPackage -Name 'RoxaZip.ShellExtension' | Remove-AppxPackage
```

The Store variant must also not offer to create that sparse package - it has the
identity already; the packaged-mode detection in the file manager takes care of
that (see the open work below).

## Store identity (assigned by Partner Center)

| Field | Value |
|---|---|
| `Package/Identity/Name` | `imacte.RoxaZip` |
| `Package/Identity/Publisher` | `CN=99CE4C4C-7CDF-4CB7-A3F5-AAB5567A3092` |
| `Package/Properties/PublisherDisplayName` | `imacte` |
| Package family name (PFN) | `imacte.RoxaZip_dy69qcvur1ke` |
| Store ID | `9P836WXHPJGZ` |
| Store page | <https://apps.microsoft.com/detail/9P836WXHPJGZ> |

The publisher is issued by the Store and must stay exactly as above, otherwise
the upload is rejected. `Package.appxmanifest` already contains these values.

## Build

```powershell
# x64 and arm64; the Store signs the uploaded package, so it stays unsigned
pwsh -File RoxaZipPackage\build-store-package.ps1 -Arch x64
pwsh -File RoxaZipPackage\build-store-package.ps1 -Arch arm64
```

Both packages go into the same Partner Center submission (a bundle is not
required). The output is `RoxaZipPackage\Output\RoxaZip_<version>_<arch>.msix`.
Upload it **unsigned** - the Store signs the package with its own certificate,
so no code signing certificate is needed for this route.

`-SourceDir` selects the built binaries (default: the newest
`build\bin-<arch>[-ndm]`), `-InstallDir` supplies `Lang\`, `RoxaZip.chm` and the
text files of the classic payload. `-IdentityName` / `-Publisher` /
`-PublisherDisplayName` / `-Version` override the manifest when needed.

## Local test before submitting

```powershell
pwsh -File RoxaZipPackage\build-store-package.ps1 -Sign -MakeCert -Install
```

This signs the package with a self-signed test certificate (the publisher in the
package is adjusted to the certificate automatically, otherwise Windows rejects
it) and registers it for the current user. Then check:

1. `%LOCALAPPDATA%\Microsoft\WindowsApps` contains `7z.exe`, `7zFM.exe`,
   `7zG.exe`, `RoxaZip.exe`, `RoxaZipFM.exe`, `RoxaZipG.exe`, and
   `7z.exe i` / `RoxaZip.exe i` run from a fresh console;
2. right-click a file and a folder: "RoxaZip" appears in the **new** Windows 11
   menu (sign out and back in, or restart Explorer, if it does not);
3. the file manager starts from the Start menu tile and from the alias.

Remove the test package again (the build script prints the exact command for the
name and publisher it used):

```powershell
Get-AppxPackage -Name 'imacte.RoxaZip' | Remove-AppxPackage
```

## Submission checklist

* [x] Partner Center: product created (`MSIX or PWA app`), name reserved
* [x] product identity values in `Package.appxmanifest`
* [ ] package built for `x64` and `arm64`
* [ ] **store listing assets** - the manifest references `StoreLogo.png`,
      `Square150x150Logo.png` and `Square44x44Logo.png` (all present in
      `Package/Assets`), but the Store listing additionally wants
      `Wide310x150Logo`, `Square71x71Logo`, `Square310x310Logo` and `LargeTile`;
* [ ] at least one screenshot (1366x768 or larger)
* [ ] description, feature list, search keywords, category (File managers)
* [ ] age rating questionnaire
* [ ] privacy policy statement (RoxaZip collects nothing and does not connect
      anywhere)
* [ ] source code link for the LGPL parts
* [ ] first submission created in Partner Center (needed once before the
      `msstore` CLI can manage submissions)

## Packaged mode

The program detects the package identity at run time
(`NShellIntegrationModern::Is_Running_Packaged()`), so the Store variant needs no
separate build:

* the options page keeps the Windows 11 menu enabled (the package provides it)
  and disables the classic modes - a packaged process cannot change the
  machine-wide registration, and the shell lists the commands of a package in the
  classic menu anyway;
* the machine-wide switches (`-ShellMenu=register|unregister|state:`,
  `-AssocAll=...`) answer with an explanation instead of failing with an HRESULT;
* opening an archive by command line (`RoxaZipFM.exe archive.7z`) still works;
* `tests/smoke-options.ps1` detects whether it runs against a packaged build and
  checks both behaviours.

## Open work

* the x64 package builds, installs and works locally (aliases, Windows 11 menu,
  file manager, options page); the arm64 package comes from CI;
* the store listing still needs the four extra tiles
  (`Wide310x150Logo`, `Square71x71Logo`, `Square310x310Logo`, `LargeTile`), the
  screenshots and the submission itself;
* the classic `-AssocAll`/shell registration of the classic build is replaced by
  the manifest in this variant (`fileTypeAssociation`,
  `fileExplorerContextMenus`).

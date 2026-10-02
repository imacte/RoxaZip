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

## Open work

* the package has not been built or installed yet - the script and the manifest
  are new; the local test below has to run before the first upload;
* packaged-mode behaviour still has to be adapted: a packaged app cannot write
  `HKLM`, so the machine-wide paths of the classic build (`-AssocAll`,
  `-ShellMenu=register`) must detect the package and explain themselves, and the
  options page must not look for the sparse `.msix` next to the binaries
  (`ShellIntegrationModern.cpp`);
* `-AssocAll`/classic shell registration in the Store variant is replaced by the
  manifest (`fileTypeAssociation`, `fileExplorerContextMenus`).

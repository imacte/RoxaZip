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

**CI builds them too**: the `do-release` job of
[build.yml](../.github/workflows/build.yml) packs the x64 and arm64 packages from
the same staged payload as the classic setup and uploads them as the workflow
artifact **"RoxaZip Store package"**. They are deliberately kept out of the
GitHub release, because an unsigned `.msix` cannot be installed by users.

`-SourceDir` selects the built binaries (default: the newest
`build\bin-<arch>[-ndm]`). If the directory also contains `Lang\`,
`RoxaZip.chm` and the text files (a staged payload, as in CI), they are taken
from there; otherwise they come from `-InstallDir`. `-IdentityName`,
`-Publisher`, `-PublisherDisplayName` and `-Version` override the manifest when
needed (`-Version` accepts `26.03` and `26.3.0.0`).

`-HideHelperApps` marks the console and the GUI helper with
`AppListEntry="none"` so that only "RoxaZip" appears in the Start menu. It
requires the **HeadlessAppBypass** waiver for the product - see the ticket text
and the procedure in [StoreListing.md](StoreListing.md).

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
* [x] store assets generated by `design/icons` and referenced by the manifest
      (`uap:DefaultTile`), see below
* [x] the x64 and arm64 packages are built by CI (`do-release` job, workflow
      artifact "RoxaZip Store package")
* [ ] at least one screenshot (1366x768 or larger)
* [ ] description, feature list, search keywords, category (File managers)
* [ ] age rating questionnaire
* [ ] privacy policy statement (RoxaZip collects nothing and does not connect
      anywhere)
* [ ] source code link for the LGPL parts
* [ ] first submission created in Partner Center (needed once before the
      `msstore` CLI can manage submissions)

### Store assets

`design/icons` generates all of them from the application icon, and
`npm run check` verifies every byte:

| file | size | used for |
|---|---|---|
| `StoreLogo.png` | 50x50 | `Properties/Logo` |
| `StoreLogo300x300.png` | 300x300 | the Store listing logo |
| `Square44x44Logo.png` | 44x44 | `uap:VisualElements` |
| `Square71x71Logo.png` | 71x71 | `uap:DefaultTile` |
| `Square150x150Logo.png` | 150x150 | `uap:VisualElements` |
| `Square310x310Logo.png` | 310x310 | `uap:DefaultTile` |
| `LargeTile.png` | 310x310 | Store listing (large tile) |
| `Wide310x150Logo.png` | 310x150 | `uap:DefaultTile` (icon centred on the canvas) |

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

* the x64 package is submitted for certification (version `26.3.0.0`); the arm64
  package exists in CI and goes out with the next update, whose version comes from
  the workflow run number;
* the HeadlessAppBypass waiver (ticket `2610020010001019`) is pending. Once the
  Store granted it, `-HideHelperApps` (or `STORE_HIDE_HELPERS: '1'` in CI) removes
  the console and the GUI helper from the Start menu;
* the whole submission process - identity, first submission, update checklist, the
  waiver and the Store error messages seen so far - is documented in
  [../DOC/StoreSubmission.md](../DOC/StoreSubmission.md);
* the classic `-AssocAll`/shell registration of the classic build is replaced by
  the manifest in this variant (`fileTypeAssociation`,
  `fileExplorerContextMenus`).

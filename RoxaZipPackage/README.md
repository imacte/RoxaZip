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

### Updates

The Store updates an installed package on its own (the user setting "Update apps
automatically" decides when); the program does not have to run for that. On top
of it the file manager offers **Help -> Check for updates**:

* the Store variant asks the Store for a newer package
  (`StoreContext.GetAppAndOptionalStorePackageUpdatesAsync`) and lets the Store
  download and install it (`RequestDownloadAndInstallStorePackageUpdatesAsync`).
  The Store shows its own consent and progress dialogs; the file manager only
  disables its window while it waits (`CShellOperationGuard`), then offers to
  restart;
* the classic installation has no package identity, so the Store cannot update
  it: it is offered the download page instead;
* after a successful update the program is started again through its app user
  model id (`shell:AppsFolder\<package family name>!RoxaZip.FileManager`),
  because the folder of the previous package version is gone.

Implementation: `CPP/7zip/UI/FileManager/StoreUpdate.{h,cpp}` (the only file that
uses the Store API) plus the menu entry and strings in `resource.{h,rc}` and the
flow in `MyLoadMenu.cpp`. `FMBuild.mak` compiles it with the C++/WinRT flags
(`-DZ7_ENABLE_STORE_UPDATE`), the same way as `ShellIntegrationModern.cpp`; builds
without that switch get the stubs and answer "not installed from the Store".

Background:
<https://learn.microsoft.com/en-us/windows/uwp/packaging/self-install-package-updates>

### Language files: where they come from, and this fork's own strings

The file manager reads its texts from `Lang\<id>.txt` next to the program and
falls back to the English string table inside `RoxaZipFM.exe`. The upstream 7-Zip
**source tree does not contain those files** - they ship inside the official
binary package (`https://www.7-zip.org/a/7z2603.exe`, 93 files under `Lang\`; the
`-src.7z` package and the git tree contain none of them).

The reviewed copies live in the **7-Zip repository**
<https://github.com/imacte/7zip> (`Lang\`, unmodified upstream files), and the
release builds take them from there:

* `.github/scripts/fetch-upstream-lang.ps1` downloads only `Lang\` (partial clone
  plus sparse checkout) into the staged payload. The store-package job and
  `do-release.cmd` call it; **if it fails, the language files of the unpacked
  upstream installer stay**, so a network problem cannot block a release;
* `.github/scripts/update-upstream-lang.ps1` extracts the files of a new upstream
  package into a folder - run it against a clone of the 7-Zip repository after an
  upstream bump, then commit and push there;
* `.github/scripts/apply-lang-additions.ps1` merges
  `.github/scripts/lang-additions\<id>.txt` into the payload language files. That
  is where the strings *this fork* adds live (**Help -> Check for updates**,
  `zh-cn.txt`); they use the numeric IDs from
  `CPP/7zip/UI/FileManager/resource.h` (the menu item by its command ID) and are
  inserted at the position the IDs require, because CLang keeps the IDs of the
  file ascending. `-Check` only verifies that a language file already carries
  them. The 7-Zip repository stays a pure upstream copy.

A language is added by dropping another file into the additions folder
(`zh-tw.txt` for example); languages without a file keep the English text.

Both call sites are wired: `build-store-package.ps1` (the Store package) and
`.github/workflows/do-release.cmd` (the classic installer payload, whose scripts
the CI windows job copies next to it).

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

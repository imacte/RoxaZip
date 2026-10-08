<!-- RoxaZip - Copyright (c) 2026 RoxaZip contributors - License: MIT, see DOC/License-MIT.txt -->
# RoxaZip in the Microsoft Store

How the Store packages are built and submitted, what the first submission used,
and what an update has to do. `RoxaZipPackage/StoreListing.md` holds the listing
text and the restricted capability justifications.

## Product identity

| Item | Value |
|---|---|
| Product | RoxaZip |
| Store ID | `9P836WXHPJGZ` |
| Store URL | <https://apps.microsoft.com/detail/9P836WXHPJGZ> |
| Package/Identity/Name | `imacte.RoxaZip` |
| Publisher | `CN=99CE4C4C-7CDF-4CB7-A3F5-AAB5567A3092` |
| Publisher display name | `imacte` |
| Package family name (Store-signed) | `imacte.RoxaZip_dy69qcvur1ke` |

The publisher comes from the Store account and must stay exactly like this; a
package with a different publisher is rejected. `build-store-package.ps1 -Sign`
replaces it with a test certificate in its staging copy only, so local test builds
never change the file in the repository.

## The package

The `store-package` job in `.github/workflows/build.yml` builds it - a separate job
from `do-release`, so a Store packaging problem can never block a release. The
artifact is called **`RoxaZip Store package`** and contains one package per
architecture:

```
RoxaZip_26.3.<run number>.0_x64.msix
RoxaZip_26.3.<run number>.0_arm64.msix
```

| Property | Rule |
|---|---|
| Version | `26.3.<run number>.0`. The Store rejects a package that is not newer than the published one, and the run number keeps it increasing. Pass another value with `-Version` (it accepts `26.03` and `26.3.0.0`). |
| Architecture | `ProcessorArchitecture` is set from `-Arch`. It used to stay `neutral`, which gave both architectures the same full name and made the Store refuse the second package. |
| Signature | Unsigned on purpose: the Store signs the uploaded package. `-Sign -Install` creates a test certificate and installs the package locally, which is only for testing. |
| Helpers | `-HideHelperApps` hides the console and the GUI helper from the Start menu. It needs the HeadlessAppBypass waiver (see below). |
| Assets | `Package/Assets` (8 PNGs) is copied into `Assets\`; the CI job stages the upstream skeleton itself (`Lang`, help file, text files). |

Local build:

```powershell
pwsh -File RoxaZipPackage\build-store-package.ps1 -ExeDir "D:\Program Files\RoxaZip"
pwsh -File RoxaZipPackage\build-store-package.ps1 -ExeDir "D:\Program Files\RoxaZip" -HideHelperApps
```

The listing screenshots are reproducible: `RoxaZipPackage/make-screenshots.ps1`
starts the installed program, opens the file manager, the options page, the
"Add to archive" dialog and the checksum dialog, and captures 1600x1000 images into
`RoxaZipPackage/Screenshots` (`05-context-menu.png` is a manual shot of the
Windows 11 context menu).

## First submission (2026-10-02, version 26.3.0.0, x64)

| Section | Value |
|---|---|
| 定价和可用性 / Pricing and availability | free (`CNY 0`), all 240 markets, open audience, discoverable in the Store, publish as soon as possible, never stop offering |
| 属性 / Properties | privacy question: no personal information; category Utilities -> File managers; display mode: nothing checked; declarations: purchase, accessibility, ink and generative AI unchecked; system requirements: keyboard and mouse |
| 年龄分级 / Age ratings | all lowest tiers (ESRB E, PEGI 3, USK 0, IARC 3+, Microsoft Store 3) |
| 程序包 / Packages | `RoxaZip_26.3.0.0_x64.msix`, device family Windows 10/11 Desktop |
| Store 一览 / Store listing | text from `RoxaZipPackage/StoreListing.md` (en-US and zh-CN), the five screenshots plus a manual context menu shot, `Package/Assets/StoreLogo300x300.png` |
| 提交选项 / Submission options | `runFullTrust` and `unvirtualizedResources` justified with the texts from `StoreListing.md`; release as soon as certification passes. The `unvirtualizedResources` request was denied on 2026-10-06 - see the next section |

## Certification result (2026-10-06): unvirtualizedResources denied

The first submission came back as **Attention needed** (review completed
2026-10-06, policy **10.6.3 Capabilities**):

> Your request to use unvirtualizedResources has been reviewed and was denied
> based on the information provided. You may want to remove the restricted
> capability and resubmit.

`unvirtualizedResources` and the `desktop6:FileSystemWriteVirtualization`
property that requires it are **removed** from
`RoxaZipPackage/Package.appxmanifest`; the package now declares only
`runFullTrust`. Nothing in the application changed - only the two lines in the
manifest. A Store package has to be built again (`build-store-package.ps1`, or
the `store-package` job in `.github/workflows/build.yml`) so that the new
manifest is inside the `.msix`, and that package is then resubmitted.

Why this costs nothing functionally:

* MSIX virtualizes writes only to `HKCU\Software` (runtime writes go to a
  per-package per-user hive) and to `%USERPROFILE%\AppData` (new files and
  folders go to a per-package location that is merged into the visible one).
  Every other location the user can write - other drives, network shares,
  removable media and the rest of the profile - is not virtualized, so packing
  and extracting archives in the real file system keeps working.
* What changes: the settings in `HKCU\Software\RoxaZip` become private to the
  package and are removed when the package is uninstalled. They are no longer
  shared with a classic RoxaZip installation, and if a user extracts an archive
  into a folder below `%AppData%`, the files land in the package-private copy.
* `runFullTrust` was not questioned, and it is the capability that actually makes
  the executables and the packaged COM server start.

The sparse package in `Package/AppxManifest.xml` is not part of a Store
submission and keeps `unvirtualizedResources`, so the settings of a classic
installation stay shared with the shell extension.

If a future version genuinely needs unvirtualized access, the request has to name
the process outside the package that must see which file or registry entry; the
[MSIX documentation](https://learn.microsoft.com/en-us/windows/msix/desktop/flexible-virtualization)
and the [property reference](https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-desktop6-filesystemwritevirtualization)
describe the (game-oriented) case Microsoft approves. On Windows 11 there is also
the narrower `<virtualization:ExcludedDirectory>` /
`<virtualization:ExcludedKey>` syntax, but it requires `unvirtualizedResources`
as well.

## Certification result of the resubmission (2026-10-07): passed, published

The resubmitted packages (`RoxaZip_26.3.23.0_x64.msix` and `_arm64.msix`, built
by the `store-package` job from commit `a216670d`, declaring only
`runFullTrust`) passed certification. Partner Center reports
**Pass with required fix**, review completed 2026-10-07, and two e-mails arrived:
"Your submission for the product RoxaZip has passed certification" and "Your
submission is processed". The product is live:
<https://apps.microsoft.com/detail/9P836WXHPJGZ>.

### The one required fix: 10.1.1.11 On Device Tiles

> Your submission installs multiple components to the device. Please make sure
> the additional installed components that are visible in the Start Menu have a
> unique name that clearly identifies which item is the main product.

The report shows the three Start entries side by side - `RoxaZip`,
`RoxaZip Console` and `RoxaZip GUI` - with the same icon, which is exactly the
three `<Application>` elements of the package. Microsoft asks for this in the
**next** submission ("Please include these changes the next time you submit your
app"), so the published 26.3.23.0 stays available while it is prepared.

Two ways to fix it, in this order:

1. **Hide the helpers (preferred).** `AppListEntry="none"` on the console and the
   GUI helper leaves a single Start entry and is the documented fix for helper
   executables; the package already supports it with
   `build-store-package.ps1 -HideHelperApps` / `STORE_HIDE_HELPERS: '1'`. It
   needs the **HeadlessAppBypass** waiver, which is still pending - see the
   "HeadlessAppBypass waiver" section below for the follow-up text to send.
2. **If the waiver is refused**, keep the entries but make it obvious which one
   is the product: give the console and the GUI helper their own icons and names
   that say they are helpers (for example `RoxaZip Console (helper)` and
   `RoxaZip GUI (helper)`). This is the fallback, not the plan - it depends on
   the reviewer, while the waiver removes the entries altogether.

Do not drop the two helper `<Application>` elements to get rid of the tiles: the
`7z.exe` and `7zG.exe` execution aliases live on them, and the file manager
cannot declare aliases for other executables.

### The Store build, verified with the Store package (2026-10-07)

The classic installation was removed (its uninstaller, the sideloaded sparse
package and `HKCU\Software\RoxaZip`), and the published package was installed from
the Store with `winget install --id 9P836WXHPJGZ --source msstore`:

| Check | Result |
|---|---|
| Package | `imacte.RoxaZip_26.3.23.0_x64`, `SignatureKind = Store`, manifest declares only `runFullTrust` |
| Execution aliases | all six present (`7z.exe`, `7zFM.exe`, `7zG.exe`, `RoxaZip*.exe`) |
| Codecs | `RoxaZip.exe i` lists zstd, brotli, lz4, lz5, lizard, bzip2, zip and the hash algorithms |
| Archive round trip | `7z.exe a test.7z -m0=zstd` -> `l` -> `t` -> `x`; SHA-256 of the extracted 2 MB file identical |
| Extraction target | the files land in the real file system, as expected outside `AppData` |
| Windows 11 context menu | the cascaded "RoxaZip" submenu appears in the new menu |
| Start menu | still three entries - the 10.1.1.11 finding above |
| Settings | the real `HKCU\Software\RoxaZip` stays untouched; the app writes into the package hive (`%LOCALAPPDATA%\Packages\imacte.RoxaZip_dxy69cxvrx1ke\SystemAppData\Helium\User.dat`) |

The Windows 11 context menu and the packaged COM surrogate work without
`unvirtualizedResources` - that is exactly the integration the old justification
claimed would break, and it does not.

### In-app updates (Help -> Check for updates)

The Store updates an installed package on its own; the menu entry is for the
customer who wants to ask. It uses the Store API
([Download and install package updates from the Store](https://learn.microsoft.com/en-us/windows/uwp/packaging/self-install-package-updates)):

| Case | Behavior |
|---|---|
| Store package, newer version published | the newer version is offered, the customer confirms, the Store downloads and installs it with its own dialogs, then RoxaZip offers to restart |
| Store package, nothing newer | "RoxaZip \<version\> is the latest version." |
| Classic installation (no package identity) | the Store cannot update it; the download page is offered |
| Developer-signed test package | the Store has no license for it, so the error path is shown - test the real path with a Store-installed build |

Files: `CPP/7zip/UI/FileManager/StoreUpdate.{h,cpp}` (the only WinRT user besides
`ShellIntegrationModern.cpp`), the menu entry and the strings in
`resource.{h,rc}`, the flow in `MyLoadMenu.cpp`, and the compile rule in
`CPP/7zip/UI/FileManager/FMBuild.mak` (`-DZ7_ENABLE_STORE_UPDATE`, C++/WinRT,
same flags as the shell integration; other builds get the stubs).

The Chinese texts of the feature are in
`.github/scripts/lang-additions/zh-cn.txt`; the packaging fetches the payload
language files from <https://github.com/imacte/7zip> and merges those entries in
(see `RoxaZipPackage/README.md`, "Language files: where they come from, and this
fork's own strings").

To verify after the next submission: keep the **older** Store version on a test
machine, publish the newer one, then Help -> Check for updates. The query alone
can be checked right away with the current Store build - it answers "latest
version" while nothing newer is published.

## Update checklist

1. The next submission has to clear **10.1.1.11 On Device Tiles**. Once the
   HeadlessAppBypass waiver arrived, set `STORE_HIDE_HELPERS: '1'` in the
   `store-package` job of `.github/workflows/build.yml` and push. The job log then
   prints `hide helper apps: True`, and the two helper applications carry
   `AppListEntry="none"`. Without the waiver, use the naming fallback from the
   section above instead.
2. Wait for the workflow, open the run, download the **`RoxaZip Store package`**
   artifact and unpack it (both architectures).
3. Partner Center -> RoxaZip -> **new submission**.
4. Packages page: upload both packages, keep **Windows 10/11 Desktop** checked.
   The version is already higher than the published one.
5. Review the other sections (they carry over, but confirm them):
   | Section | Check |
   |---|---|
   | Pricing and availability | still free, all markets |
   | Properties | privacy = no, category = Utilities -> File managers |
   | Age ratings | the generated ratings are reused |
   | Store listing | text and screenshots (update them if the release changed something visible) |
   | Submission options | only the `runFullTrust` box - `unvirtualizedResources` is gone from the manifest (see "Certification result" above) |
6. Submit for certification. Certification usually takes hours and can take up to
   three working days; the product is published automatically afterwards because
   the release option is "as soon as certification passes".

## HeadlessAppBypass waiver

The Store rejects a package that uses `AppListEntry="none"` unless the product has
the `HeadlessAppBypass` waiver:

> Package acceptance validation error: The package file ... specifies a headless
> app. You don't have permission to create headless apps. Please update
> `AppListEntry="none"` in the AppxManifest file and also ensure you have the
> waiver "HeadlessAppBypass" associated to this app.

Ticket **2610020010001019** was submitted on 2026-10-02 and is waiting for the
Store team. It was created through the **Create support case (MSA)** link on
<https://developer.microsoft.com/en-us/windows/support/> - program *Windows
Developer Center*, problem type *App Management*, support plan *Professional No
Charge*, contact by e-mail. The waiver is granted per product.

Routes that do **not** work for an individual developer account: the "Create
support case (Entra ID)" link (the business Engage Center answers "no access to
any workspace"), and `partnerops@microsoft.com` (other developers reported no
answer for a month).

While the waiver is missing, the packages ship with three visible Start menu
entries: `RoxaZip` (file manager), `RoxaZip Console` (command line, provides the
`7z.exe` alias) and `RoxaZip GUI` (progress window, provides the `7zG.exe` alias).
Once it is granted, `-HideHelperApps` leaves only `RoxaZip`.

## Errors seen, and what caused them

| Store message | Cause | Fix |
|---|---|---|
| "specifies a headless app ... you don't have permission to create headless apps" | `AppListEntry="none"` without the waiver | request the waiver, or keep the helper entries visible |
| "the following restricted capabilities require approval: runFullTrust, unvirtualizedResources" | restricted capabilities used without a justification (first submission only) | fill the box on the submission options page (`StoreListing.md` has the text); `unvirtualizedResources` is no longer declared, so it has no box any more |
| "all .msix packages must be uniquely identified by their full name ... `imacte.RoxaZip_26.3.0.0_Neutral` ... have different content" | the manifest `Identity` had no `ProcessorArchitecture`, so x64 and arm64 shared one full name | `-Arch` sets `ProcessorArchitecture` |
| uploading a package whose version is not higher than the published one | reusing `26.3.0.0` for an update | the version comes from the CI run number |
| "10.6.3 Capabilities - your request to use unvirtualizedResources has been reviewed and was denied" | the manifest declared the `unvirtualizedResources` restricted capability (with `desktop6:FileSystemWriteVirtualization`) and Microsoft did not approve it for a file manager | remove the capability and the property from `RoxaZipPackage/Package.appxmanifest` and resubmit (see "Certification result" above) |
| a restricted capability justification that stops in the middle of a sentence ("...the common dialogs, the re") | the "Submission options" justification boxes hold **500 characters** and cut off the rest without a warning; the text from `StoreListing.md` was 706 characters | use the 479-character `runFullTrust` text from `StoreListing.md` and check that it ends with "cannot start." |
| "10.1.1.11 On Device Tiles - your submission installs multiple components to the device ... additional installed components that are visible in the Start Menu have a unique name that clearly identifies which item is the main product" (Pass with required fix, 2026-10-07) | the package declares three `<Application>` elements, so the Start menu shows `RoxaZip`, `RoxaZip Console` and `RoxaZip GUI` with the same icon | hide the two helpers with `-HideHelperApps` once the HeadlessAppBypass waiver is granted, or give them their own names and icons; include it in the next submission (see "Certification result of the resubmission") |

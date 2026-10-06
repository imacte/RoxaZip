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

## Update checklist

1. If the HeadlessAppBypass waiver arrived, set `STORE_HIDE_HELPERS: '1'` in the
   `store-package` job of `.github/workflows/build.yml` and push. The job log then
   prints `hide helper apps: True`.
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

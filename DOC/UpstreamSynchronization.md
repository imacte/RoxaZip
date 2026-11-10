<!-- RoxaZip - Copyright (c) 2026 RoxaZip contributors - License: MIT, see DOC/License-MIT.txt -->
# RoxaZip upstream synchronization

RoxaZip tracks 7-Zip, the 7-Zip ZS fork and the bundled codec libraries. This
file records which upstream revision the current tree is based on, so that a
future synchronization can be reviewed as a diff against a known point.

## Pinned revisions

| Component | Path | Revision |
|---|---|---|
| 7-Zip (mainline) | `CPP/7zip`, `C/` | 26.06 |
| 7-Zip ZS (`mcmilk/7-Zip-zstd`) | `CPP/7zip`, `C/` | `430e33f6` ("Merge pull request #592 from sebres/upd-26.06", 2026-11-10) |
| Zstandard | `C/zstd` | 1.5.7 |
| Brotli | `C/brotli` | 1.2.1 |
| LZ4 | `C/lz4` | 1.10.0 |
| LZ5 | `C/lz5` | 1.5 |
| Lizard | `C/lizard` | 2.1 |
| Fast LZMA2 | `C/fast-lzma2` | 1.0.1 |
| darkmodelib | `DarkMode/lib` | git submodule |

The release version of the fork itself is 26.06 (7-Zip ZS release 1), see
`C/7zVersion.h`.

## 2026-11-10 synchronization

Merged the upstream source changes from `b5ac55ff` through `430e33f6`:

- 7-Zip 26.04-26.06 archive parser and decoder fixes, improved Z and Mach-O
  unpacking, and support for Linux `split` suffixes that grow in length.
- Brotli 1.2.1, including the decoder out-of-bounds write fix.
- Lizard/Zstandard error-enum isolation and the no-crypto SFX build fix.
- Compiler compatibility updates, including macOS Clang source fixes.
- The upstream Tcl test improvements, retaining RoxaZip's localized Windows
  error handling and locked-file detection. `tests/split.test` also checks
  growing Linux split suffixes and conventional numbered volumes.

RoxaZip keeps its own branding, Explorer integration, Store manifest settings,
language overlay and versioned release names. The core, installer and Store
package versions now use 26.06 / 26.6. The matching installer payload is fetched
from the upstream GitHub release mirror. No language resource IDs were added
by this upstream interval; the reviewed language source remains `imacte/7zip`.
All 93 language files match the 26.06 installer after normalizing line endings.

CI now supports manual dispatch and pins the Windows ARM64 compiler to the
14.4 toolset for both builds and compiled tests (upstream issue #572). The
existing Linux runner is retained. Upstream's additional macOS workflows were
not adopted: RoxaZip currently distributes Windows and Linux packages, and the
upstream jobs assume upstream executable and artifact names.

Validated locally with Visual Studio 2022 (MSVC 14.44):

- Full Windows x64 build without dark mode, x64 standalone File Manager with
  dark mode, no-crypto SFXSetup, and x86 standalone console build.
- Tcl suite: 49 passed / 1 platform skip for each x64 console variant;
  50 passed for x86, including all four split-volume regressions. The multi-file
  roundtrip test uses two threads to avoid ZIP/Zstd exhausting the x86 address
  space on hosts with many CPU cores; the thread-option tests still run.
- Options, shortcut migration, LZ5/Lizard frame tests at three optimization
  levels, release publishing mocks and all 109 generated icon assets.
- Options-window smoke checks with and without dark mode, all six encryption
  modes with header encryption on/off and wrong-password rejection, and
  embedded-archive scanning beyond 8 MiB.
- Unsigned x64 Store package creation, including its version, resource index
  and the two hidden helper applications. No package was installed or published.

Linux and ARM64 builds were not run locally; those remain covered by CI after
the branch is pushed.

## How the local changes are marked

Deviations from upstream in shared source files are wrapped in:

```c
// **** RoxaZip Modification Start ****
...
// **** RoxaZip Modification End ****
```

The markers make the local deviations easy to find and to re-check when a new
upstream revision is merged.

Two rules keep the diff against upstream small:

1. **Upstream assets keep their upstream names.** The source tree (`CPP/7zip`),
   the makefiles (`7zip.mak`, `7zip_gcc.mak`, `C/7zip_gcc_c.mak`), the developer
   directories (`C/Util/7zipInstall`, `C/Util/7zipUninstall`), the icons
   (`7zipLogo.ico`, `C/Util/7zipInstall/7zip.ico`) and the plugin interface
   GUIDs (`k_7zip_GUID_*`) are not renamed. Only the shipped product and the
   identifiers that users, scripts or the shell see carry the RoxaZip name.
2. **Everything that is renamed is listed** in [RoxaZip.md](RoxaZip.md),
   together with the registry keys, the CLSID and the help file.

## Merging a new upstream revision

```bash
git remote add upstream https://github.com/mcmilk/7-Zip-zstd.git   # once
git fetch upstream
git diff HEAD upstream/master -- CPP/7zip C          # review first
git merge upstream/master
```

Then check the marked regions, update the table above, and run the build and the
test suite (`tests/run-options-tests.ps1`, `tests/test-branding-shortcuts.ps1`,
`tests/smoke-options.ps1`, `tests/test-release-publishing.ps1`,
`design/icons` -> `npm run check`).

## Language files (payload data, not in the source tree)

`Lang\*.txt` are not part of the upstream source tree or of this repository: the
reviewed copies live in the 7-Zip repository
<https://github.com/imacte/7zip> (`Lang\`), and the release builds fetch them
from there. After an upstream bump, refresh that folder:

```powershell
pwsh -File .github\scripts\update-upstream-lang.ps1 -Installer 7z2606.exe `
    -RoxaZip build\bin-x64-ndm\RoxaZip.exe -OutDir <clone-of-imacte/7zip>\Lang
# then in the clone: git add Lang && git commit && git push
```

The strings this fork adds stay in this repository
(`.github/scripts/lang-additions\`) and are merged when the payload is packaged.
Details: `RoxaZipPackage/README.md`.

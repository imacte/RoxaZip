<!-- RoxaZip - Copyright (c) 2026 RoxaZip contributors - License: MIT, see DOC/License-MIT.txt -->
# RoxaZip upstream synchronization

RoxaZip tracks 7-Zip, the 7-Zip ZS fork and the bundled codec libraries. This
file records which upstream revision the current tree is based on, so that a
future synchronization can be reviewed as a diff against a known point.

## Pinned revisions

| Component | Path | Revision |
|---|---|---|
| 7-Zip (mainline) | `CPP/7zip`, `C/` | 26.03 |
| 7-Zip ZS (`mcmilk/7-Zip-zstd`) | `CPP/7zip`, `C/` | `b5ac55ff` ("Add cascaded AEGIS algorithm and fix x86 buffer alignment issue", 2026-10-01); last merged in `45fd4f5f` |
| Zstandard | `C/zstd` | 1.5.7 |
| Brotli | `C/brotli` | 1.2.0 |
| LZ4 | `C/lz4` | 1.10.0 |
| LZ5 | `C/lz5` | 1.5 |
| Lizard | `C/lizard` | 2.1 |
| Fast LZMA2 | `C/fast-lzma2` | 1.0.1 |
| darkmodelib | `DarkMode/lib` | git submodule |

The release version of the fork itself is 26.03 (7-Zip ZS release 1), see
`C/7zVersion.h`.

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
pwsh -File .github\scripts\update-upstream-lang.ps1 -Installer 7z2604.exe `
    -RoxaZip build\bin-x64-ndm\RoxaZip.exe -OutDir <clone-of-imacte/7zip>\Lang
# then in the clone: git add Lang && git commit && git push
```

The strings this fork adds stay in this repository
(`.github/scripts/lang-additions\`) and are merged when the payload is packaged.
Details: `RoxaZipPackage/README.md`.

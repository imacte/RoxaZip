# RoxaZip

RoxaZip is an archive manager for Windows and Linux, based on [7-Zip](https://www.7-zip.org/)
and the [7-Zip ZS](https://github.com/mcmilk/7-Zip-zstd) fork. It adds additional codecs and
hashers, cascade encryption modes, dark mode, Explorer integration and format-specific icons.
Upstream authorship and licenses are preserved.

[![Latest release](https://img.shields.io/github/v/release/imacte/RoxaZip?include_prereleases)](https://github.com/imacte/RoxaZip/releases)

## Download and install

The [releases](https://github.com/imacte/RoxaZip/releases) provide four packages:

| Package | Contents |
|---|---|
| `RoxaZip-<version>-windows-<arch>.exe` | Windows setup for x64, x86 and ARM64; `-ndm` builds omit dark mode |
| `RoxaZip-<version>-linux-<arch>-<compiler>.tar.gz` | Linux binaries for x64/ARM64, built with GCC or Clang |
| `RoxaZip-<version>-codecs-<arch>.7z` | codec plugins for an existing mainline 7-Zip |
| `RoxaZip-<version>-totalcmd.7z` | Total Commander plugin |

There are two ways to install it:

1. **Full setup** - installs the file manager, the Explorer integration and the codecs.
2. **Codec plugin only** - copy the plugin DLLs into the `Codecs` folder of your existing
   7-Zip installation; no GUI changes and no additional hashers.

## Command line

| Binary | Description |
|---|---|
| `RoxaZip` | full tool; loads its formats and codecs from `RoxaZip.dll` / `RoxaZip.so` |
| `RoxaZipZ` | standalone, all formats, no external plugins |
| `RoxaZipA` | standalone, fewer formats (minimal + LZ4 and the hashes) |
| `RoxaZipR` | minimal standalone, 7z only (FLZMA2, Zstandard) |

Windows builds use the `.exe` suffix; Linux packages contain the same names without it.

```bash
RoxaZip a archive.7z dir/ -m0=zstd -mx19        # Zstandard, level 19
RoxaZip a archive.7z dir/ -m0=lz4 -mx9          # LZ4
RoxaZip a archive.7z dir/ -m0=flzma2 -mx9       # Fast LZMA2
RoxaZip x archive.7z -oout/                     # extract
RoxaZip a secret.7z dir/ -p -mhe=on -mem=axa    # encrypted, header encrypted
```

All methods, their levels, the encryption modes, hashing and sample `RoxaZip i` output:
[DOC/CLI.md](DOC/CLI.md).

## What you get

- **Codecs**: Zstandard 1.5.7, Brotli 1.2.0, LZ4 1.10.0, LZ5 1.5, Lizard 2.1 and
  Fast LZMA2 1.0.1 - usable inside `.7z` archives and for `.zst`, `.br`, `.lz4`, `.lz5`
  and `.liz` files.
- **Hashers**: CRC32/64, MD2/4/5, SHA1/256/384/512, SHA3-256/384/512, XXH32/64,
  BLAKE2sp and BLAKE3.
- **Encryption**: 7zAES plus XChaCha20, XChaCha20-Poly1305, AES+XChaCha20-Poly1305 (AXP),
  AES+XChaCha20+Ascon (AXA) and XChaCha20+AES+AEGIS (XAA), all with optional header
  encryption.
- **Shell**: dark mode, format-specific icons and a Windows 11 context menu.

## Explorer integration (Windows)

- The setup registers the classic context menu entry "RoxaZip".
- For the modern Windows 11 menu, build and register the sparse package:
  [Package/README.md](Package/README.md).
- `Options -> System` in the file manager controls the file associations and the menu mode.

## Plugins for other programs

- **Mainline 7-Zip**: copy the DLLs from the codecs package into its `Codecs` folder.
- **Total Commander**: replace `tc7z.dll` and `tc7z64.dll` with the files from the
  totalcmd package.
- **Far Manager**: copy `RoxaZip.dll` from the RoxaZip installation to
  `C:\Program Files\Far Manager\Plugins\ArcLite\7z.dll` (Far expects that file name).

## Build

Windows (`nmake` needs a Visual Studio developer prompt):

```cmd
nmake PLATFORM=x64          REM one target, run from its directory, e.g. CPP\7zip\Bundles\Fm
CPP\build-it.cmd -no-init   REM the full set; PLATFORM, SUBSYS, ROOT, OUTDIR and LFLAGS from CI
```

Linux: `CC=gcc CXX=g++ OUTDIR=$PWD/build-gcc CPP/build-lx.sh` (use `clang`/`clang++` for the
Clang build). Both are exactly what [.github/workflows/build.yml](.github/workflows/build.yml)
does; upstream build documentation is in [DOC/readme.txt](DOC/readme.txt).

All shipped binaries and libraries use RoxaZip file names (`RoxaZipFM.exe`, `RoxaZip.dll`,
`RoxaZipShell.dll`, ...); no `7z*` files are installed. The mapping from the previous names,
the registry and CLSID changes, the upgrade steps and how to bring the old command names back
are documented in [DOC/RoxaZip.md](DOC/RoxaZip.md).

## Credits and license

- Based on [7-Zip](https://www.7-zip.org/) by Igor Pavlov and the
  [7-Zip ZS](https://github.com/mcmilk/7-Zip-zstd) fork by Tino Reichardt,
  Sergey G. Brester and fzxx. Bundled codec, hash and crypto libraries keep their own
  authorship, see [COPYING](COPYING).
- Icons by AlexGal, masamunecyrus and Mr4Mike4; dark mode via
  [darkmodelib](https://github.com/ozone10) by ozone10.
- License of the archive manager, the codecs and the bundled libraries: see
  [COPYING](COPYING) and [DOC/License.txt](DOC/License.txt) - GNU LGPL
  v2.1-or-later as the main license, plus BSD, MIT and public-domain parts and
  the unRAR license restriction for the RAR code.
- The tooling and documentation written for RoxaZip (packaging, release scripts,
  tests, icon pipeline, [DOC/CLI.md](DOC/CLI.md), [DOC/RoxaZip.md](DOC/RoxaZip.md),
  ...) are MIT licensed - see [DOC/License-MIT.txt](DOC/License-MIT.txt); every
  such file carries a `License: MIT` header.
- Upstream project and benchmarks: <https://mcmilk.de/projects/7-Zip-zstd/>.
- Donations to the upstream author: <https://www.paypal.me/TinoReichardt>.

## Documentation

- [DOC/CLI.md](DOC/CLI.md) - command line reference, methods, encryption, hashing, sample output
- [DOC/RoxaZip.md](DOC/RoxaZip.md) - branding, file names, compatibility with existing installations
- [Package/README.md](Package/README.md) - Windows 11 context menu (sparse package)
- [DOC/readme.txt](DOC/readme.txt) - upstream build instructions and module layout
- [DOC/UpstreamSynchronization.md](DOC/UpstreamSynchronization.md) - pinned upstream revisions and modification markers
- [design/icons/README.md](design/icons/README.md) - icon pipeline

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

Executable and library names (`7z`, `7zz`, `7zFM.exe`, `7z.dll`, `7-zip.dll`,
etc.) remain compatible with scripts, plugins, file associations and package
manifests. Registry keys, ProgIDs, shell CLSIDs, window classes and sparse-package
identity/signing subject are retained so settings and registrations keep working.
Their legacy identifiers do not determine the displayed product name.

Upstream language files keep their `7-Zip` signature. Visible translated product
names are adapted when loaded. The bundled upstream help and license documents
continue to credit 7-Zip and its authors.

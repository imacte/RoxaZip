# RoxaZip command line

Full reference for the RoxaZip binaries. The short overview is in
[../README.md](../README.md); this file holds the complete examples, the
encryption table and sample output.

## Binaries

| Binary | Standalone | Capabilities |
|---|---|---|
| `RoxaZip` | no | all formats; loads them from `RoxaZip.dll` (Windows) / `RoxaZip.so` (Linux) and from plugins in `Codecs\` / `Formats\` |
| `RoxaZipZ` | yes | all formats, no external plugins |
| `RoxaZipA` | yes | 7z/xz/cab/zip/gzip/bzip2/tar plus LZ4 and the hashes |
| `RoxaZipR` | yes | 7z only (FLZMA2, Zstandard) |

Windows builds use the `.exe` suffix; Linux packages contain the same four names
without it. The old `7z`, `7za`, `7zz` and `7zr` names are described in
[RoxaZip.md](RoxaZip.md).

## Compression examples

```bash
RoxaZip a archiv.7z -m0=zstd -mx0   Zstandard fastest mode, without BCJ preprocessor
RoxaZip a archiv.7z -m0=zstd -mx1   Zstandard fast mode, with BCJ preprocessor on executables
RoxaZip a archiv.7z -m0=zstd -mx..  ...
RoxaZip a archiv.7z -m0=zstd -mx21  Zstandard 2nd slowest mode, with BCJ preprocessor on executables
RoxaZip a archiv.7z -m0=zstd -mx22  Zstandard ultra mode, with BCJ preprocessor on executables

RoxaZip a archiv.7z -m0=lz4 -mx0    LZ4 fastest mode, without BCJ preprocessor
RoxaZip a archiv.7z -m0=lz4 -mx1    LZ4 fast mode, with BCJ preprocessor on executables
RoxaZip a archiv.7z -m0=lz4 -mx12   LZ4 ultra mode, with BCJ preprocessor on executables

RoxaZip a archiv.7z -m0=lz5 -mx0    LZ5 fastest mode, without BCJ preprocessor
RoxaZip a archiv.7z -m0=lz5 -mx1    LZ5 fast mode, with BCJ preprocessor on executables
RoxaZip a archiv.7z -m0=lz5 -mx16   LZ5 ultra mode, with BCJ preprocessor on executables

RoxaZip a archiv.7z -m0=flzma2 -mx1 Fast LZMA2 fastest mode, with BCJ preprocessor on executables
RoxaZip a archiv.7z -m0=flzma2 -mx9 Fast LZMA2 ultra mode, with BCJ preprocessor on executables

RoxaZip a archiv.7z -m0=brotli -mx11
RoxaZip a archiv.7z -m0=lizard -mx49
```

Compression levels per codec: Zstandard 1..22, Brotli 0..11, LZ4 1..12, LZ5 1..15,
Lizard 10..49 (10..19 fastLZ4, 20..29 LIZv1, 30..39 fastLZ4+Huffman,
40..49 LIZv1+Huffman), Fast LZMA2 1..9.

Single-file formats and streaming:

```bash
RoxaZip a file.zst file              # .zst / .tzst
RoxaZip a file.br  file              # .br
RoxaZip a file.lz4 file              # .lz4
RoxaZip a file.lz5 file              # .lz5
RoxaZip a file.liz file              # .liz

RoxaZip x -so test.tar.zst | RoxaZip l -si -ttar   # list a zstd compressed tar
RoxaZip x -so test.tar.lz  | RoxaZip l -si -ttar   # list a lzip compressed tar
```

The full installation handles ZIP archives that use Zstandard compression, and
squashfs images compressed with LZ4 or Zstandard.

## Encryption

Header encryption (`-mhe=on`) is supported by every mode.

| Mode | `-mem=` | Key derivation | Authentication |
|---|---|---|---|
| 7zAES | `aes256`, `aes-256` | SHA-256 iterative hashing | - |
| XChaCha20 | `xchacha20` | SHA-256 iterative hashing | - |
| XChaCha20-Poly1305 | `xchacha20poly1305`, `xchacha20-poly1305` | SHA-256 iterative hashing | Poly1305 MAC |
| AES+XChaCha20-Poly1305 (AXP) | `axp`, `aesxchacha20poly1305`, `aes+xchacha20-poly1305` | PBKDF2-HMAC-SHA512 + HKDF-BLAKE2sp | Poly1305 MAC |
| AES+XChaCha20+Ascon (AXA) | `axa`, `aesxchacha20ascon`, `aes+xchacha20+ascon` | PBKDF2-HMAC-SHA512 + HKDF-BLAKE2sp | Ascon-128a tag |
| XChaCha20+AES+AEGIS (XAA) | `xaa`, `xchacha20aesaegis`, `xchacha20+aes+aegis` | PBKDF2-HMAC-SHA512 + HKDF-BLAKE2sp | AEGIS-256 tag |

```bash
# AES-256
RoxaZip a archive.7z -ppassword -mhe=on -mem=aes256

# XChaCha20 / XChaCha20-Poly1305
RoxaZip a archive.7z -ppassword -mhe=on -mem=xchacha20
RoxaZip a archive.7z -ppassword -mhe=on -mem=xchacha20poly1305

# cascades
RoxaZip a archive.7z -ppassword -mhe=on -mem=axp
RoxaZip a archive.7z -ppassword -mhe=on -mem=axa
RoxaZip a archive.7z -ppassword -mhe=on -mem=xaa
```

Ascon is the winner of the NIST Lightweight Cryptography standardization
project; AEGIS-256 is specified in RFC 10032.

## Hashing

```bash
RoxaZip h -scrcSHA256 archive.7z
RoxaZip h -scrcBLAKE3  archive.7z
```

Available hashers:

| 4 | 8 | 16 | 20 | 32 | 48 | 64 |
|---|---|---|---|---|---|---|
| CRC32, XXH32 | CRC64, XXH64 | MD2, MD4, MD5 | SHA1 | SHA256, SHA3-256, BLAKE2sp, BLAKE3 | SHA384, SHA3-384 | SHA512, SHA3-512 |

## Sample output of `RoxaZip i`

```
RoxaZip 26.03 : Copyright (c) 1999- Igor Pavlov, 2016- Tino Reichardt, 2022- Sergey G. Brester, 2026- fzxx : 2026-09-05

Libs:
 0  c:\Program Files\RoxaZip\RoxaZip.dll
 1  C:\Program Files\RoxaZip\Codecs\Iso7z.64.dll

Formats:
...
 0 CK            xz       xz txz (.tar) FD 7 z X Z 00
 0               Z        z taz (.tar)  1F 9D
 0 CK            zstd     zst zstd tzst (.tar) tzstd (.tar) 0 x F D 2 F B 5 2 5 . . 0 x F D 2 F B 5 2 8 00
 0 C   F         7z       7z            7 z BC AF ' 1C
 0     F         Cab      cab           M S C F 00 00 00 00
...

Codecs:
 0 4ED   303011B BCJ2
 0  EDF  3030103 BCJ
 0  EDF  3030205 PPC
 0  EDF  3030401 IA64
 0  EDF  3030501 ARM
 0  EDF  3030701 ARMT
 0  EDF  3030805 SPARC
 0  EDF    20302 Swap2
 0  EDF    20304 Swap4
 0  ED     40202 BZip2
 0  ED         0 Copy
 0  ED     40109 Deflate64
 0  ED     40108 Deflate
 0  EDF        3 Delta
 0  ED        21 LZMA2
 0  ED     30101 LZMA
 0  ED     30401 PPMD
 0   D     40301 Rar1
 0   D     40302 Rar2
 0   D     40303 Rar3
 0   D     40305 Rar5
 0  ED   4F71102 BROTLI
 0  ED   4F71104 LZ4
 0  ED   4F71106 LIZARD
 0  ED   4F71105 LZ5
 0  ED   4F71101 ZSTD
 0  ED        21 FLZMA2
 0  EDF  6F10701 7zAES
 0  EDF  6F00181 AES256CBC
 0  EDF  6F10702 XChaCha20
 0  EDF  6F10703 XChaCha20-Poly1305
 0  EDF  6F10704 AES256CTR+XChaCha20-Poly1305
 0  EDF  6F10705 AES256CTR+XChaCha20+Ascon
 0  EDF  6F10706 XChaCha20+AES+AEGIS

Hashers:
 0   32      202 BLAKE2sp
 0   32      204 BLAKE3
 0    4        1 CRC32
 0    8        4 CRC64
 0   16      205 MD2
 0   16      206 MD4
 0   16      207 MD5
 0   20      201 SHA1
 0   32        A SHA256
 0   48      208 SHA384
 0   64      209 SHA512
 0   32      20A SHA3-256
 0   48      20B SHA3-384
 0   64      20C SHA3-512
 0    4      20D XXH32
 0    8      20E XXH64
```

## Codec plugin for mainline 7-Zip

1. download `RoxaZip-<version>-codecs-<arch>.7z` from the
   [releases](https://github.com/imacte/RoxaZip/releases)
2. create a `Codecs` folder in the 7-Zip installation and put the plugin DLLs in it
   (x64: `C:\Program Files\7-Zip\Codecs`, x86: `C:\Program Files (x86)\7-Zip\Codecs`)
3. alternatively replace the `7z.dll` of that installation
4. verify with `7z.exe i`; the plugins show up as further entries under `Libs`

The plugin DLLs only add the codecs to the 7-Zip container format: you can create
`.7z` archives, but not standalone `.zst` / `.lz4` / `.lz5` files. When compressing
executables, disable the BCJ2 filter explicitly and use BCJ instead:

```bash
7z a archiv.7z -m0=bcj -m1=zstd -mx1    fast mode, with BCJ preprocessor
7z a archiv.7z -m0=bcj -m1=zstd -mx22   ultra mode, with BCJ preprocessor
7z a archiv.7z -m0=bcj -m1=brotli -mxN
7z a archiv.7z -m0=bcj -m1=lizard -mxN
7z a archiv.7z -m0=bcj -m1=lz4 -mxN
7z a archiv.7z -m0=bcj -m1=lz5 -mxN
7z a archiv.7z -m0=bcj -m1=flzma2 -mxN
```

## Plugins for Total Commander and Far Manager

- **Total Commander**: download `RoxaZip-<version>-totalcmd.7z` and replace the
  files `tc7z.dll` and `tc7z64.dll` in the Total Commander directory.
- **Far Manager**: copy `RoxaZip.dll` from the RoxaZip installation to
  `C:\Program Files\Far Manager\Plugins\ArcLite\7z.dll` (Far expects that file
  name) and restart Far.

## Benchmarks

Benchmarks are run with the standalone Linux binary `RoxaZipZ` on an idle Dell
PowerEdge R6615 (AMD EPYC 9354P, 32 cores, 128 GB DDR5, AlmaLinux 9), using the
[Silesia compression corpus](https://sun.aei.polsl.pl/~sdeor/index.php?page=silesia).

Compression is measured single-threaded per method with
`RoxaZip a test.7z -mmt=1 -m0=MethodX`, decompression with `RoxaZip t test.7z`;
memory and time come from a [modified GNU time](https://github.com/mcmilk/7-Zip-Benchmarking/blob/master/linux/time-1.9.tr.diff)
and the [upstream test script](https://github.com/mcmilk/7-Zip-Benchmarking/blob/master/linux/runtests.sh).

![Compression Speed vs Ratio](https://mcmilk.de/projects/7-Zip-zstd/dl/2026-01-03/01-ratio-vs-compr.png "Compression Speed vs Ratio")
![Decompression Speed vs Ratio](https://mcmilk.de/projects/7-Zip-zstd/dl/2026-01-03/02-ratio-vs-decompr.png "Decompression Speed vs Ratio")
![Compression Speed per Level](https://mcmilk.de/projects/7-Zip-zstd/dl/2026-01-03/03-compr-per-level.png "Compression Speed per Level")
![Decompression Speed per Level](https://mcmilk.de/projects/7-Zip-zstd/dl/2026-01-03/04-decompr-per-level.png "Decompression Speed per Level")
![Memory at Compression](https://mcmilk.de/projects/7-Zip-zstd/dl/2026-01-03/05-mem-compr.png "Memory usage at Compression")
![Memory at Decompression](https://mcmilk.de/projects/7-Zip-zstd/dl/2026-01-03/06-mem-decompr.png "Memory usage at Decompression")

## Screenshots

![Explorer integration](https://mcmilk.de/projects/7-Zip-zstd/Add-To-Archive.png "Add to Archive Dialog with ZSTD options")
![File Manager](https://mcmilk.de/projects/7-Zip-zstd/Fileman.png "File Manager with the Listing of an Archive")
![Methods](https://mcmilk.de/projects/7-Zip-zstd/Methods2.png "Methods")
![Hashes](https://mcmilk.de/projects/7-Zip-zstd/Hashes.png "Hashes")
![Settings](https://mcmilk.de/projects/7-Zip-zstd/Settings.png "Settings for storing the history within the registry.")

## Notes

- Several history settings are not stored by default; the original 7-Zip behaviour
  can be restored in `Tools -> Options -> Settings`.
- Antivirus false positives: the release downloads are built on the fly by GitHub
  Actions and can be verified against the published `SHA256SUMS.txt`. Report false
  positives to the antivirus vendor rather than opening an issue here.

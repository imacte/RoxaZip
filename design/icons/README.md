# 7-Zip ZS icon family

Original SVG artwork inspired by [WinRAR's bound-book archive icon](https://www.win-rar.com/):
three colored volumes with shaded spines, cream pages, a brown leather strap and
a silver buckle. Icons have no text or label plates; top-volume colors distinguish
formats. Format names in preview sheets are captions outside the artwork. Backgrounds
are transparent. The book geometry is drawn in `stacked-books.mjs`; no downloaded
WinRAR artwork is embedded. The monochrome
toolbar is unchanged.
The pipeline covers all 61 application-owned image resources:
34 archive ICOs, 9 application/installer/SFX ICOs, 14 toolbar BMPs, one shell menu
BMP and three package PNGs. The third-party DarkMode demo icon and Windows-owned
folder/drive/file icons are outside this set.

See [design overview](preview-books.png), [light preview](preview-light.png), [dark preview](preview-dark.png), and
[small-size inspection](preview-sizes.png).
`manifest.json` maps every source to its existing resource path; resource IDs and
archive index order are preserved. Brotli and Fast-LZMA2 codec resources now use
their own format icons. Bundled FM also embeds all 34 archive icons with explicit
extension mappings, preserving the original application/About indices 0/1. This
avoids the previous fallback to a single app icon when no external 7z.dll exists.

## Editing and regeneration

Edit the SVG masters in `src/`, then from this directory run:

```powershell
npm ci
npm run build
npm run check
pwsh -File verify-windows.ps1
```

After a native build, also check the compiled group-icon order and extension maps:

```powershell
pwsh -File verify-windows.ps1 -FileManager ../../CPP/7zip/Bundles/Fm/x64/RoxaZipFM.exe -ArchiveLibrary ../../CPP/7zip/Bundles/Format7zF/x64/RoxaZip.dll
```

The ordinary build is font-independent: SVG lettering is already outlined. It
uses pinned resvg to rasterize the masters and writes resources directly into
the existing C, CPP and Package paths. It skips writing unchanged files. The
check command compares every generated resource byte-for-byte without writing.
The Windows check exercises all 430 icon-size loads, DIB alpha, image-list
insertion, and coverage of tracked image resources.

`create-sources.mjs` is the optional geometry/palette bootstrap, not part of the
normal build. Running it **resets SVG edits and the manifest**. It requires
Segoe UI Regular (`C:/Windows/Fonts/segoeui.ttf`, or `ICON_FONT`). Preview-only
captions use system fonts; the icon artwork itself does not.

The base top-volume palette is 7Z `#419BCC`, ZIP `#D5A94B`, RAR `#A457AA`, ISO
`#96A0AB` and WIM `#8297A4`. Other formats mix the original palette with white at
an 88:12 ratio. Middle and bottom volumes blend each accent toward blue and green.
The bootstrap retains original inputs so repeated runs do not lighten again.
Production uses the vivid palette: the base accents are brightened without
changing their hue, and middle/bottom volumes blend toward brighter blue and green.
Applications use `#CB69DB` / `#3CB5F1` / `#5ED17E` and their existing action badges.
The generator explicitly disables labels for every format, application and size.

## Small sizes and Windows integration

ICOs contain 16, 20, 24, 32, 40, 48, 64, 96, 128 and 256 pixel frames. Sizes
through 48 use straight-alpha DIBs and AND masks; larger frames use PNG to keep
resource size down. Native 16/20/24/32px masters are selected via `sizeSources`
in the manifest (`-small.svg` is the 32px master). They use whole-pixel book covers,
simplified pages and a metal buckle. The vivid 16px artwork occupies 16x15 pixels,
up from 14x12. Larger book bodies scale by 1.12 within the same canvas; action
badges remain at their original size and position.
The remaining sizes use shaded, perspective book masters. `stacked-books.mjs` and
`small-icons.mjs` retain an optional label parameter for comparison previews;
production generation passes `false` for labels and `true` for the vivid treatment. The optional labeled comparison uses
Segoe UI Semibold (`C:/Windows/Fonts/seguisb.ttf`, or `ICON_SMALL_FONT`).

Toolbar BMPs retain the original 48x36 and 24x24 dimensions. They now carry
premultiplied BGRA, are loaded as DIB sections, and are tinted to the current
system/dark-mode text color before insertion into the image list. The menu BMP
also uses premultiplied alpha. Package assets are checked in and the packaging
script reports missing assets instead of silently drawing the previous logo.

The NMAKE resource rule tracks image changes for incremental rebuilds. Normal
native builds consume the committed ICO/BMP/PNG files and do not need Node.
Rebuilding/replacing application binaries is required before installed copies
can show the new resources. This work does not change registry associations or
install/register a package.

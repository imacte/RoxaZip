<!-- RoxaZip - Copyright (c) 2026 RoxaZip contributors - License: MIT, see DOC/License-MIT.txt -->
# Known issues

## Fixed: LZ5 and Lizard stored-block decoding with MSVC 2026 optimization

Reported and fixed 2026-09-29. The original Windows ARM64 failures were in
CI run 36522834035 and remained reproducible in run 36524356816.

Small LZ5 archives written with `-tlz5` or `-m0=lz5` failed to read back:
`main--pipe-a-to-e`, `main--pipe-a-to-e-mx0`, and `main--compress-mx0`
reported `Data Error` or `The data is invalid`.

After fixing LZ5, the same loops reached Lizard and exposed the identical defect
there (`main--pipe-a-to-e-mx0` and `main--compress-mx0`). Both codecs are fixed.

The small-frame regression also exposed a Lizard encoder overflow with one-byte
input: the frame encoder gives the block compressor zero output capacity, but it
still wrote its header. The compressor now rejects that capacity before writing,
allowing the frame encoder to store the byte uncompressed. AddressSanitizer
confirmed the original overflow and validates the fix.

The frame decoder read the block header twice, first masking out the stored-block
flag to obtain the size, then reading the flag again. MSVC 2026 with `/O1`
miscompiled this path: valid stored (uncompressed) blocks entered the compressed
block decoder. This also reproduces in a standalone x64 build without LTCG;
the `/Od` control builds pass on both x64 and ARM64. It is not a checksum mismatch
or a stdin/threading defect.

The LZ5 and Lizard frame decoders now read the block header once and derive both
the size and stored-block flag from that value. The archive format and checksum checks are
unchanged. Native x64 and ARM64 `/O1` and `/Od` tests pass with this change.

`tests/lz-frame.c` covers both codecs' original payloads, small stored blocks,
compressed blocks, fragmented input/output, and rejection of corrupted content checksums.
`tests/run-lz-frame-tests.ps1` runs it in the Windows CI matrix with `/O1`,
the codecs' `/O2 /Ob3` flags, and `/Od`, so non-LTCG optimization remains covered
on all three architectures.

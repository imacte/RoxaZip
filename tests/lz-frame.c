/*
 * RoxaZip
 * Copyright (c) 2026 RoxaZip contributors
 * License: MIT - see DOC/License-MIT.txt
 */
/* Regression for stored-block decoding with MSVC 2026 /O1 (notably ARM64). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef TEST_LIZARD
#  include "lizard_frame_static.h"
#  define FRAME(name) LizardF_##name
#  define FRAME_VERSION LIZARDF_VERSION
#  define CODEC_NAME "lizard"
static const int levels[] = {10, 20};
#else
#  include "lz5frame_static.h"
#  define FRAME(name) LZ5F_##name
#  define FRAME_VERSION LZ5F_VERSION
#  define CODEC_NAME "lz5"
static const int levels[] = {1, 3};
#endif

static int decode(const unsigned char *frame, size_t frameSize,
    const unsigned char *input, size_t size, size_t inputChunk,
    size_t outputChunk, int corrupt)
{
    FRAME(decompressionContext_t) ctx;
    unsigned char *output = (unsigned char *)calloc(size + 1, 1);
    size_t read = 0, written = 0, result;
    int failed;
    if (!output) exit(2);
    result = FRAME(createDecompressionContext)(&ctx, FRAME_VERSION);
    if (FRAME(isError)(result)) exit(2);
    do {
        size_t consumed = frameSize - read;
        size_t produced = size + 1 - written;
        if (consumed > inputChunk) consumed = inputChunk;
        if (produced > outputChunk) produced = outputChunk;
        result = FRAME(decompress)(ctx, output + written, &produced,
            frame + read, &consumed, NULL);
        read += consumed;
        written += produced;
        if (!consumed && !produced) break;
    } while (result != 0 && !FRAME(isError)(result));
    if (corrupt)
        failed = result != (size_t)-FRAME(ERROR_contentChecksum_invalid);
    else
        failed = result != 0 || read != frameSize || written != size || memcmp(input, output, size) != 0;
    if (failed)
        printf("::error::" CODEC_NAME " size=%u inputChunk=%u outputChunk=%u corrupt=%d: %s, read=%u written=%u\n",
            (unsigned)size, (unsigned)inputChunk, (unsigned)outputChunk, corrupt,
            FRAME(getErrorName)(result), (unsigned)read, (unsigned)written);
    FRAME(freeDecompressionContext)(ctx);
    free(output);
    return failed;
}

static int check(const unsigned char *input, size_t size, int level, int checksum)
{
    FRAME(preferences_t) prefs = {0};
    unsigned char *frame;
    size_t capacity, compressed;
    int failures = 0;
    prefs.compressionLevel = level;
    prefs.frameInfo.contentSize = size;
    prefs.frameInfo.contentChecksumFlag = checksum ? FRAME(contentChecksumEnabled) : FRAME(noContentChecksum);
    capacity = FRAME(compressFrameBound)(size, &prefs);
    frame = (unsigned char *)malloc(capacity);
    if (!frame) exit(2);
    compressed = FRAME(compressFrame)(frame, capacity, input, size, &prefs);
    if (FRAME(isError)(compressed)) {
        printf("::error::" CODEC_NAME " compress size=%u level=%d: %s\n", (unsigned)size, level, FRAME(getErrorName)(compressed));
        exit(2);
    }
    /* Whole frame, split headers/blocks/suffix, and limited output space. */
    failures += decode(frame, compressed, input, size, compressed, size + 1, 0);
    failures += decode(frame, compressed, input, size, 1, size + 1, 0);
    failures += decode(frame, compressed, input, size, compressed, 7, 0);
    if (checksum) {
        frame[compressed - 1] ^= 1;
        failures += decode(frame, compressed, input, size, compressed, size + 1, 1);
        failures += decode(frame, compressed, input, size, 1, 7, 1);
    }
    free(frame);
    return failures;
}

int main(void)
{
    const unsigned char small[] = CODEC_NAME ": This is a test string passed to stdin\r\n";
    unsigned char data[4096];
    size_t i, levelIndex;
    int checksum, failures = 0;
    for (i = 0; i < sizeof(data); ++i) data[i] = (unsigned char)(i * 7 + (i >> 5));
    for (levelIndex = 0; levelIndex < sizeof(levels) / sizeof(levels[0]); ++levelIndex) {
        for (checksum = 0; checksum <= 1; ++checksum) {
            failures += check(small, sizeof(small) - 1, levels[levelIndex], checksum);
            /* Small inputs exercise stored blocks; the larger one compresses. */
            for (i = 0; i < 80; ++i) failures += check(data, i, levels[levelIndex], checksum);
            failures += check(data, sizeof(data), levels[levelIndex], checksum);
        }
    }
    printf(CODEC_NAME " frame tests: %d failures\n", failures);
    return failures ? 1 : 0;
}

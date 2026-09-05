#!/usr/bin/env bash
set -euo pipefail
: "${LEGACY_BIN:?Missing legacy toolchain bin directory}"
: "${LEGACY_SDK:?Missing iOS SDK directory}"
export PATH="$LEGACY_BIN:$PATH"
mkdir -p build-legacy
"$LEGACY_BIN/clang" --version
for arch in armv7 arm64; do
    minimum=6.0
    if [ "$arch" = arm64 ]; then minimum=7.0; fi
    for source in main OMGGenerator; do
        "$LEGACY_BIN/clang" \
            -target "$arch-apple-ios$minimum" \
            -isysroot "$LEGACY_SDK" \
            -miphoneos-version-min="$minimum" \
            -fobjc-arc -fblocks -Os \
            -Wall -Wextra -Werror=unguarded-availability \
            -Wno-unused-parameter \
            -c "LegacyApp/$source.m" -o "build-legacy/$source-$arch.o"
    done
    # iOS 6 provides the ARC operations used here. Link the compiled objects
    # directly without asking the driver for the unavailable libarclite shim.
    "$LEGACY_BIN/clang" \
        -target "$arch-apple-ios$minimum" -isysroot "$LEGACY_SDK" \
        -miphoneos-version-min="$minimum" \
        "build-legacy/main-$arch.o" "build-legacy/OMGGenerator-$arch.o" \
        -framework UIKit -framework Foundation -framework CoreGraphics -lobjc \
        -o "build-legacy/app-$arch"
done
"$LEGACY_BIN/lipo" -create build-legacy/app-armv7 build-legacy/app-arm64 \
    -output build-legacy/OriginalMotivationGeneratorLegacy
"$LEGACY_BIN/lipo" -info build-legacy/OriginalMotivationGeneratorLegacy

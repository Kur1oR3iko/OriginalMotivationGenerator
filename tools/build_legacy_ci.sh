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
    "$LEGACY_BIN/clang" \
        -target "$arch-apple-ios$minimum" \
        -isysroot "$LEGACY_SDK" \
        -miphoneos-version-min="$minimum" \
        -fobjc-arc -fno-objc-link-runtime -fblocks -Os \
        -Wall -Wextra -Werror=unguarded-availability \
        -Wno-unused-parameter \
        LegacyApp/main.m LegacyApp/OMGGenerator.m \
        -framework UIKit -framework Foundation -lobjc \
        -o "build-legacy/app-$arch"
done
"$LEGACY_BIN/lipo" -create build-legacy/app-armv7 build-legacy/app-arm64 \
    -output build-legacy/OriginalMotivationGeneratorLegacy
"$LEGACY_BIN/lipo" -info build-legacy/OriginalMotivationGeneratorLegacy

"""Validate real Mach-O slices before creating the unsigned CI IPA."""
from pathlib import Path
import json
import plistlib
import shutil
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
build = ROOT / "build-legacy"
binary = build / "OriginalMotivationGeneratorLegacy"
raw = binary.read_bytes()
magic, count = struct.unpack_from(">II", raw)
assert magic == 0xCAFEBABE and count == 2, "Expected a two-slice universal binary"
report = {"signed": False, "runtime_tested": False, "architectures": {}}
for index in range(count):
    cpu, subtype, offset, size, align = struct.unpack_from(">IIIII", raw, 8 + index * 20)
    name = {12: "armv7", 0x100000C: "arm64"}[cpu]
    assert name not in report["architectures"]
    if name == "armv7":
        assert subtype & 0xFFFFFF == 9, "Expected ARM v7"
    data = raw[offset:offset + size]
    header = struct.unpack_from("<7I", data)
    assert header[0] == (0xFEEDFACF if name == "arm64" else 0xFEEDFACE)
    assert header[1] == cpu and header[3] == 2, "Expected a Mach-O executable"
    position = 32 if name == "arm64" else 28
    dependencies = []
    minimum = None
    for _ in range(header[4]):
        command, length = struct.unpack_from("<II", data, position)
        assert length >= 8 and position + length <= len(data)
        if command == 0x25:  # LC_VERSION_MIN_IPHONEOS
            minimum = struct.unpack_from("<I", data, position + 8)[0]
        elif command == 0x32:  # LC_BUILD_VERSION
            platform, minimum = struct.unpack_from("<II", data, position + 8)
            assert platform == 2
        elif command in (0xC, 0x80000018, 0x8000001F):
            start = struct.unpack_from("<I", data, position + 8)[0]
            dependency = data[position + start:position + length].split(b"\0")[0].decode()
            assert dependency.startswith(("/usr/lib/", "/System/Library/Frameworks/")), dependency
            assert "swift" not in dependency.lower(), dependency
            dependencies.append(dependency)
        position += length
    expected = (7 if name == "arm64" else 6) << 16
    assert minimum == expected, (name, minimum)
    report["architectures"][name] = {"minimum_os": f"{minimum >> 16}.0", "dependencies": dependencies}
assert set(report["architectures"]) == {"armv7", "arm64"}

app = build / "Payload/OriginalMotivationGeneratorLegacy.app"
app.mkdir(parents=True, exist_ok=True)
shutil.copy2(binary, app / binary.name)
(app / binary.name).chmod(0o755)
for resource in (ROOT / "LegacyApp").glob("*.png"):
    shutil.copy2(resource, app / resource.name)
shutil.copy2(ROOT / "LegacyApp/Words.plist", app / "Words.plist")
info = plistlib.loads((ROOT / "LegacyApp/Info.plist").read_bytes())
info.update(CFBundleExecutable=binary.name, CFBundleName=binary.name,
            CFBundleIdentifier="com.kurio.original-motivation-generator",
            CFBundleSupportedPlatforms=["iPhoneOS"], UIDeviceFamily=[1, 2])
# Linux has no Apple's Interface Builder compiler. PNG launch images work
# with this pre-iOS-13 SDK; modern screen sizes may use compatibility mode.
info.pop("UILaunchStoryboardName", None)
(app / "Info.plist").write_bytes(plistlib.dumps(info))
(app / "PkgInfo").write_bytes(b"APPL????")
with zipfile.ZipFile(build / "OriginalMotivationGenerator-iOS6-14-unsigned.ipa", "w", zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(build))
(build / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))

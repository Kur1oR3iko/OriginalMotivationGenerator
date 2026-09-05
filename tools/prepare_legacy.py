"""Refresh legacy word data and PNG resources; requires Python 3 and Pillow."""
from pathlib import Path
import plistlib
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
app = ROOT / "LegacyApp"
source = (ROOT / "App/KurioPhraseGenerator.swift").read_text(encoding="utf-8")
pools = {}
for name in ("verbs", "adjectives", "nouns"):
    match = re.search(r'private static let ' + name + r' = words\("""(.*?)"""\)', source, re.S)
    words = [word.strip() for word in match[1].split("、") if word.strip()]
    assert len(words) == 225, (name, len(words))
    pools[name] = words
(app / "Words.plist").write_bytes(plistlib.dumps(pools, fmt=plistlib.FMT_XML, sort_keys=False))
icon = Image.open(ROOT / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png").convert("RGB")
for name, size in {"Icon.png": 57, "Icon@2x.png": 114, "Icon-72.png": 72,
                   "Icon-72@2x.png": 144, "Icon-60@2x.png": 120,
                   "Icon-60@3x.png": 180, "Icon-76.png": 76,
                   "Icon-76@2x.png": 152, "Icon-83.5@2x.png": 167}.items():
    icon.resize((size, size), Image.Resampling.LANCZOS).save(app / name)
for name, size in {"Default.png": (320, 480), "Default@2x.png": (640, 960),
                   "Default-568h@2x.png": (640, 1136),
                   "Default-Landscape~ipad.png": (1024, 768),
                   "Default-Landscape@2x~ipad.png": (2048, 1536)}.items():
    Image.new("RGB", size, "white").save(app / name)
print("Legacy resources refreshed: 3 x 225 words, 9 icons, 5 launch images")

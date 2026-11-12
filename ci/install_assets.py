#!/usr/bin/env python3
"""Fetch licensed CC0 models and Arabic font for Merchants City.
Used by Android CI. Assets are committed into the game repository for reproducibility.
"""
from __future__ import annotations
import json
import pathlib
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "assets" / "cc0_manifest.json").read_text("utf8"))
BASE = f"https://raw.githubusercontent.com/Hidencod/tge-assets/{DATA['source_commit']}/"
OUT = ROOT / "assets" / "models"

def fetch(url: str) -> bytes:
    last = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "MerchantsCity-AssetInstaller/1.0"})
            with urllib.request.urlopen(req, timeout=35) as response:
                return response.read()
        except Exception as exc:
            last = exc
            time.sleep(1.5 + attempt)
    raise RuntimeError(f"Download failed {url}: {last}")

def main() -> None:
    count = 0
    missing = []
    for pack, names in DATA["packs"].items():
        for name in names:
            relative = f"packs/{pack}/{name}.glb"
            destination = OUT / pack / (name + ".glb")
            if destination.exists() and destination.stat().st_size >= 100:
                count += 1
                continue
            content = fetch(BASE + relative)
            if len(content) < 100 or not content.startswith(b"glTF"):
                missing.append(relative)
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
            print(f"Installed {relative}: {len(content)} bytes")
            count += 1
    font_out = ROOT / "assets" / "fonts"
    font_out.mkdir(parents=True, exist_ok=True)
    font_file = font_out / "NotoNaskhArabic.ttf"
    if not font_file.exists():
        url = "https://raw.githubusercontent.com/google/fonts/main/ofl/notonaskharabic/NotoNaskhArabic%5Bwght%5D.ttf"
        content = fetch(url)
        if len(content) < 10000:
            raise RuntimeError("Arabic font download unexpectedly small")
        font_file.write_bytes(content)
    license_out = ROOT / "assets" / "licenses"
    license_out.mkdir(parents=True, exist_ok=True)
    ofl_out = license_out / "OFL-NotoNaskhArabic.txt"
    if not ofl_out.exists():
        ofl_out.write_bytes(fetch("https://raw.githubusercontent.com/google/fonts/main/ofl/notonaskharabic/OFL.txt"))
    expected = sum(len(values) for values in DATA["packs"].values())
    if missing or count != expected:
        raise RuntimeError(f"Missing assets: {missing}. Got {count}/{expected}")
    print(f"ASSETS OK: {count} CC0 Kenney GLB models, plus Arabic font (OFL)")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build a clean, shareable Nock-VERSION.zip from the Nock/ addon folder.

The zip has one top-level Nock/ folder, ready to extract into
World of Warcraft/_forever_/Interface/AddOns.

It includes only the addon (lua, toc, xml, tga, txt). No tests, art
masters, previews, backups, or SavedVariables.
"""
from __future__ import annotations

import re
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "Nock"
OUT_DIR = ROOT / "share"
ALLOWED_EXT = {".lua", ".toc", ".xml", ".tga", ".txt"}
SKIP_PARTS = {"preview", "previews", "__pycache__", ".git"}


def read_version() -> str:
    toc = (ADDON / "Nock.toc").read_text(encoding="utf-8")
    m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
    if not m:
        raise SystemExit("Could not read ## Version from Nock/Nock.toc")
    return m.group(1)


def copy_addon(stage: Path) -> list[str]:
    copied: list[str] = []
    for path in sorted(ADDON.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ADDON)
        if any(part.startswith(".") or part in SKIP_PARTS for part in rel.parts):
            continue
        if path.suffix.lower() not in ALLOWED_EXT:
            continue
        dest = stage / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        copied.append(rel.as_posix())
    return copied


def pack(version: str | None = None) -> Path:
    version = version or read_version()
    toc = (ADDON / "Nock.toc").read_text(encoding="utf-8")
    if "## Interface: 16001" not in toc:
        raise SystemExit("Nock.toc Interface is not 16001")
    if f"## Version: {version}" not in toc:
        raise SystemExit(f"Nock.toc Version is not {version}")

    stage_root = ROOT / ".release-stage"
    if stage_root.exists():
        shutil.rmtree(stage_root)
    stage = stage_root / "Nock"
    stage.mkdir(parents=True)
    copied = copy_addon(stage)
    for need in ("Nock.toc", "Nock.lua", "INSTALL.txt", "Bindings.xml"):
        if not (stage / need).exists():
            raise SystemExit(f"missing {need} in staged addon")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"Nock-{version}.zip"
    if out.exists():
        out.unlink()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(stage.rglob("*")):
            if path.is_file():
                zf.write(path, Path("Nock") / path.relative_to(stage))
    shutil.rmtree(stage_root)

    names = zipfile.ZipFile(out).namelist()
    tops = {n.split("/")[0] for n in names}
    if tops != {"Nock"}:
        raise SystemExit(f"zip top-level entries should be only Nock/, got {tops}")
    print(f"Wrote {out}  ({out.stat().st_size} bytes, {len(names)} files, {len(copied)} copied)")
    return out


if __name__ == "__main__":
    pack(sys.argv[1] if len(sys.argv) > 1 else None)

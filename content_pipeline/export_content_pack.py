#!/usr/bin/env python3
"""Package the compiled content database into a distributable content pack.

Produces ``dist/IELTS-Free-Content-<version>.zip`` containing the content
database and its manifest, plus a ``SHA256SUMS.txt`` file.

Standard library only.
"""
from __future__ import annotations

import hashlib
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = ROOT / "assets" / "seed"
DIST_DIR = ROOT / "dist"
DB_FILE = SEED_DIR / "ielts_content_v1.db"
MANIFEST_FILE = SEED_DIR / "manifest.json"


def sha256_of(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if not DB_FILE.exists() or not MANIFEST_FILE.exists():
        print("ERROR: run build_content_db.py first.", file=sys.stderr)
        return 2

    manifest = json.loads(MANIFEST_FILE.read_text(encoding="utf-8"))
    version = manifest.get("contentVersion", "0.0.0")

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    archive = DIST_DIR / f"IELTS-Free-Content-{version}.zip"

    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        bundle.write(DB_FILE, DB_FILE.name)
        bundle.write(MANIFEST_FILE, MANIFEST_FILE.name)

    checksum = sha256_of(archive)
    (DIST_DIR / "SHA256SUMS.txt").write_text(
        f"{checksum}  {archive.name}\n",
        encoding="utf-8",
    )

    print("IELTS Free — content pack export")
    print(f"  archive : {archive.relative_to(ROOT)}")
    print(f"  sha256  : {checksum}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="$repo_root/dist"
love_file="$dist_dir/RogueKeys.love"

mkdir -p "$dist_dir"

echo "==> Packaging $love_file"
python3 - "$repo_root" "$love_file" <<'PY'
import os
import sys
import zipfile
from pathlib import Path

repo_root = Path(sys.argv[1])
love_file = Path(sys.argv[2])
root_files = ("main.lua", "conf.lua")
source_dirs = ("engine", "modules", "states", "lib", "data", "resources", "tests")

for relative_path in (*root_files, *source_dirs):
    if not (repo_root / relative_path).exists():
        raise SystemExit(f"BUILD FAILED: required path is missing: {relative_path}")

with zipfile.ZipFile(love_file, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for filename in root_files:
        archive.write(repo_root / filename, filename)

    for dirname in source_dirs:
        source_dir = repo_root / dirname
        for current_dir, dirnames, filenames in os.walk(source_dir):
            dirnames[:] = sorted(name for name in dirnames if not name.startswith("."))
            for filename in sorted(filenames):
                if filename.startswith("."):
                    continue
                path = Path(current_dir) / filename
                archive.write(path, path.relative_to(repo_root).as_posix())
PY

echo "BUILD OK"
echo "  .love : $love_file"

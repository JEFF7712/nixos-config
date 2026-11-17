#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
iris-python "$repo_root/tests/quickshell/test_wallpaper_layout.py"

fixture_dir=$(mktemp -d "${TMPDIR:-/tmp}/quickshell-wallpaper-layout.XXXXXX")
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir "$fixture_dir/services"
cp "$repo_root/home/configs/quickshell/services/WallpaperLayout.qml" "$fixture_dir/services/"
cp "$repo_root/tests/quickshell/integration/wallpaper-layout/"{shell.qml,helper.py} "$fixture_dir/"
QT_QPA_PLATFORM=offscreen timeout 10s quickshell --no-color -p "$fixture_dir"

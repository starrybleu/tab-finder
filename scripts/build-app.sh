#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle_path="$project_root/outputs/Tab Finder.app"
binary_path="$project_root/.build/release/TabFinder"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_root/.build/module-cache"

cd "$project_root"
swift build -c release

if [[ -d "$bundle_path" ]]; then
    rm -R "$bundle_path"
fi

mkdir -p "$bundle_path/Contents/MacOS"
cp "$binary_path" "$bundle_path/Contents/MacOS/TabFinder"
cp "$project_root/Config/Info.plist" "$bundle_path/Contents/Info.plist"

codesign --force --sign - --options runtime \
    --entitlements "$project_root/Config/TabFinder.entitlements" \
    "$bundle_path"
codesign --verify --deep --strict "$bundle_path"

#!/usr/bin/env bash
set -euo pipefail

release_dir="${1:?release directory required}"
output_dir="${2:?output directory required}"
version="${3:?version required}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][A-Za-z0-9.-]+)?$ ]] || {
  echo "Invalid version: $version" >&2
  exit 1
}
release_dir="$(cd "$release_dir" && pwd)"
exe="$release_dir/miriago-desktop"
[[ -x "$exe" && -s "$exe" ]] || { echo "Missing Linux executable: $exe" >&2; exit 1; }

# Validate every requested bundle before publishing any output.
shopt -s nullglob
appimages=("$release_dir"/bundle/appimage/*.AppImage)
debs=("$release_dir"/bundle/deb/*.deb)
rpms=("$release_dir"/bundle/rpm/*.rpm)
validate_bundle() {
  local kind="$1"
  shift
  [[ $# -eq 1 ]] || { echo "Expected exactly one $kind bundle" >&2; exit 1; }
  [[ -s "$1" ]] || { echo "Empty $kind bundle" >&2; exit 1; }
}
validate_bundle AppImage "${appimages[@]}"
validate_bundle deb "${debs[@]}"
validate_bundle rpm "${rpms[@]}"

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
package_dir="$output_dir/MiriaGo-linux"
[[ ! -e "$package_dir" ]] || { echo "Package directory already exists: $package_dir" >&2; exit 1; }
mkdir -p "$package_dir/MiriaGoData"
cp "$exe" "$package_dir/MiriaGo"
chmod +x "$package_dir/MiriaGo"
zip_path="$output_dir/MiriaGo-v$version-linux-x64.zip"
[[ ! -e "$zip_path" ]] || { echo "ZIP already exists: $zip_path" >&2; exit 1; }
(cd "$output_dir" && zip -rq "$zip_path" MiriaGo-linux)
cp "${appimages[0]}" "$output_dir/MiriaGo-v$version-linux-x64.AppImage"
chmod +x "$output_dir/MiriaGo-v$version-linux-x64.AppImage"
cp "${debs[0]}" "$output_dir/MiriaGo-v$version-linux-x64.deb"
cp "${rpms[0]}" "$output_dir/MiriaGo-v$version-linux-x64.rpm"
for extension in zip AppImage deb rpm; do
  test -s "$output_dir/MiriaGo-v$version-linux-x64.$extension"
done

#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(dirname "$here")"
control="$here/deb/DEBIAN/control"

version="$(awk -F': ' '/^Version:/ {print $2; exit}' "$control")"
if [ -z "$version" ]; then
    echo "error: could not read Version from $control" >&2
    exit 1
fi

install -m 755 "$root/src/opencode-box" "$here/deb/usr/bin/opencode-box"
dpkg-deb --build --root-owner-group "$here/deb" "$here/opencode-box_${version}_all.deb" > /dev/null

echo "built $here/opencode-box_${version}_all.deb"
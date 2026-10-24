#!/usr/bin/env bash
# Downloads General Sans from Fontshare into app/assets/fonts/.
# Its licence (ITF Free Font License) allows embedding it in the app but not
# sharing the font files, so they are not in git: each developer fetches their
# own copy. Run once before building.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/general-sans.zip" "https://api.fontshare.com/v2/fonts/download/general-sans"
for w in Regular Medium Semibold; do
  unzip -o -q -j "$tmp/general-sans.zip" "GeneralSans_Complete/Fonts/OTF/GeneralSans-$w.otf" -d app/assets/fonts
done
echo "General Sans installed in app/assets/fonts/"

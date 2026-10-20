#!/bin/bash
# Usage: Tools/release.sh 1.1  -> builds, makes EarShare.dmg + EarShare.zip, publishes GitHub release v1.1
set -euo pipefail
cd "$(dirname "$0")/.."
V=${1:?version, e.g. 1.1}
PY=${PYTHON:-python3}   # needs `pip install dmgbuild`
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $V" Info.plist
./build.sh
rm -f build/EarShare.dmg
"$PY" -m dmgbuild -s Tools/dmg_settings.py -D root="$PWD" "EarShare" build/EarShare.dmg
[ "${DRY_RUN:-}" = 1 ] && { echo "dry run: build/EarShare.dmg"; exit 0; }
gh release create "v$V" build/EarShare.dmg build/EarShare.zip --title "EarShare $V" --generate-notes

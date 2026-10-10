#!/usr/bin/env bash
set -euo pipefail
APP_NAME="${1:-Caffeine}"
MODE="${2:-run}"
[[ "$APP_NAME" == Caffeine ]] || { echo 'This repository builds Caffeine.' >&2; exit 2; }
BUNDLE_ID="personal.harinaralasetty.Caffeine"
APP_VERSION=1.3
APP_BUILD=4
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *) echo 'Modes: run, --build-only, --verify, --debug, --logs, --telemetry' >&2; exit 2;; esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
swift build --product "$APP_NAME" --jobs 2
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp -X "$(swift build --show-bin-path)/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -X "$ROOT_DIR/Caffeine/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
mkdir -p "$APP_BUNDLE/Contents/Resources/Badges"
cp -X "$ROOT_DIR/Caffeine/Resources/Badges/catalog.json" "$ROOT_DIR/Caffeine/Resources/Badges/"*.png "$APP_BUNDLE/Contents/Resources/Badges/"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>$APP_BUILD</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
PLIST
if [[ "$APP_NAME" == Caffeine ]]; then
  echo '<key>LSUIElement</key><true/>' >> "$APP_BUNDLE/Contents/Info.plist"
fi
echo '<key>CFBundleIconFile</key><string>AppIcon.icns</string>' >> "$APP_BUNDLE/Contents/Info.plist"
echo '</dict></plist>' >> "$APP_BUNDLE/Contents/Info.plist"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"
[[ "$MODE" == --build-only ]] && exit 0
# Stop only instances launched from this project's staging bundle.
while IFS= read -r pid; do
  [[ -n "$pid" ]] || continue
  executable="$(ps -p "$pid" -o comm=)"
  [[ "$executable" == "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]] && kill -TERM "$pid"
done < <(pgrep -x "$APP_NAME" || true)
case "$MODE" in
  --debug) exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME";;
  *) /usr/bin/open "$APP_BUNDLE";;
esac
case "$MODE" in
  --verify)
    sleep 1
    if ! /usr/bin/python3 - "$APP_BUNDLE/Contents/MacOS/$APP_NAME" <<'PY'
import subprocess, sys
paths = subprocess.check_output(['ps', '-axo', 'comm='], text=True).splitlines()
sys.exit(0 if sys.argv[1] in [path.strip() for path in paths] else 1)
PY
    then
      echo "No process running from $APP_BUNDLE; an installed instance may have prevented a second launch." >&2
      exit 1
    fi
    ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"";;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"";;
esac

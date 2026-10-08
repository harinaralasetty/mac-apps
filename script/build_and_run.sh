#!/usr/bin/env bash
set -euo pipefail
APP_NAME="${1:-Caffeine}"
MODE="${2:-run}"
case "$APP_NAME" in Caffeine) BUNDLE_ID="personal.harinaralasetty.Caffeine";; MicMute) BUNDLE_ID="local.codex.MicMute";; *) echo 'Choose Caffeine or MicMute' >&2; exit 2;; esac
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *) echo 'Modes: run, --build-only, --verify, --debug, --logs, --telemetry' >&2; exit 2;; esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
swift build --product "$APP_NAME" --jobs 2
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp -X "$(swift build --show-bin-path)/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [[ "$APP_NAME" == MicMute ]]; then
  cp -X "$ROOT_DIR/MicMute/Resources/"{AppIcon.icns,MicLive.png,MicMuted.png,MicUnavailable.png} "$APP_BUNDLE/Contents/Resources/"
else
  cp -X "$ROOT_DIR/Caffeine/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
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
  --verify) sleep 1; pgrep -x "$APP_NAME" >/dev/null;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"";;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\"";;
esac

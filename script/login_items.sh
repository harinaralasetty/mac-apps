#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-status}"
APP_NAME="${2:-Caffeine}"
case "$MODE" in enable|disable|status) ;; *) echo 'Usage: login_items.sh enable|disable|status [Caffeine]' >&2; exit 2;; esac
[[ "$APP_NAME" == Caffeine ]] || { echo "This script manages Caffeine only." >&2; exit 2; }
APPS=(Caffeine)
USER_DOMAIN="gui/$(id -u)"
for APP in "${APPS[@]}"; do
  LABEL="personal.harinaralasetty.${APP}.login"
  PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
  APP_PATH="${CAFFEINE_INSTALL_DIR:-/Applications}/$APP.app"
  if [[ -z "${CAFFEINE_INSTALL_DIR:-}" && -f "$PLIST" ]]; then
    APP_PATH="$(/usr/bin/python3 - "$PLIST" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as file:
    job = plistlib.load(file)
args = job.get('ProgramArguments', [])
assert len(args) == 3 and args[:2] == ['/usr/bin/open', '-a']
print(args[2])
PY
)"
  fi
  case "$MODE" in
    enable)
      [[ -d "$APP_PATH" ]] || { echo "Missing $APP_PATH" >&2; exit 1; }
      mkdir -p "$HOME/Library/LaunchAgents"
      # Reject an existing different job rather than overwriting it.
      if [[ -f "$PLIST" ]]; then
        /usr/bin/python3 - "$PLIST" "$LABEL" "$APP_PATH" <<'PY'
import sys, plistlib
with open(sys.argv[1], 'rb') as file: value = plistlib.load(file)
assert value['Label'] == sys.argv[2]
assert value['ProgramArguments'] == ['/usr/bin/open', '-a', sys.argv[3]]
assert value.get('RunAtLoad') is True
PY
      else
        /usr/bin/python3 - "$PLIST" "$LABEL" "$APP_PATH" <<'PY'
import sys, plistlib
with open(sys.argv[1], 'xb') as file:
    plistlib.dump({'Label':sys.argv[2], 'ProgramArguments':['/usr/bin/open','-a',sys.argv[3]], 'RunAtLoad':True, 'LimitLoadToSessionType':'Aqua'}, file)
PY
        chmod 644 "$PLIST"
      fi
      /bin/launchctl enable "$USER_DOMAIN/$LABEL"
      if ! /bin/launchctl print "$USER_DOMAIN/$LABEL" >/dev/null 2>&1; then
        /bin/launchctl bootstrap "$USER_DOMAIN" "$PLIST"
      fi
      ;;
    disable)
      if /bin/launchctl print "$USER_DOMAIN/$LABEL" >/dev/null 2>&1; then /bin/launchctl bootout "$USER_DOMAIN/$LABEL"; fi
      [[ ! -f "$PLIST" ]] || mv "$PLIST" "$PLIST.disabled"
      ;;
  esac
  if [[ -f "$PLIST" ]]; then
    /usr/bin/plutil -lint "$PLIST"
    /bin/launchctl print "$USER_DOMAIN/$LABEL"
    /bin/launchctl print-disabled "$USER_DOMAIN" | /usr/bin/awk -v label="$LABEL" 'index($0,label)'
  else
    echo "$APP: login startup not configured by this project"
  fi
done

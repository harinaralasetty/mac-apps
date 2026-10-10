#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${CAFFEINATE_UI_INSTALL_DIR:-/Applications}"
[[ "$INSTALL_DIR" == /* ]] || { echo 'CAFFEINATE_UI_INSTALL_DIR must be an absolute path.' >&2; exit 2; }
LOGIN=false
APPS=()
for ARG in "$@"; do
  case "$ARG" in
    CaffeinateUI) APPS+=("$ARG");;
    --login) LOGIN=true;;
    --help|-h) echo 'Usage: install.sh [CaffeinateUI] [--login]'; exit 0;;
    *) echo "Unknown option: $ARG" >&2; exit 2;;
  esac
done
if [[ ${#APPS[@]} -eq 0 ]]; then APPS=(CaffeinateUI); fi
mkdir -p "$INSTALL_DIR"
[[ -w "$INSTALL_DIR" ]] || { echo "Cannot write $INSTALL_DIR. Choose CAFFEINATE_UI_INSTALL_DIR=\"\$HOME/Applications\"." >&2; exit 1; }
for APP in "${APPS[@]}"; do
  "$ROOT_DIR/script/build_and_run.sh" "$APP" --build-only
  /usr/bin/python3 - "$ROOT_DIR" "$INSTALL_DIR" "$APP" <<'PY'
import pathlib, subprocess, hashlib, os, signal, time, plistlib
root, location, name = pathlib.Path(__import__('sys').argv[1]), pathlib.Path(__import__('sys').argv[2]), __import__('sys').argv[3]
display = 'Caffeinate UI'
source, target = root/'dist'/(display+'.app'), location/(display+'.app')
legacy = location/'Caffeine.app'
expected = 'personal.harinaralasetty.Caffeine'
def identity(app):
    with (app/'Contents/Info.plist').open('rb') as file: return plistlib.load(file)['CFBundleIdentifier']
def digest(app):
    value = hashlib.sha256()
    for file in sorted(app.rglob('*')):
        if file.is_file():
            value.update(str(file.relative_to(app)).encode()+b'\0'); value.update(file.read_bytes())
    return value.hexdigest()
assert identity(source) == expected
subprocess.run(['codesign','--verify','--strict',str(source)],check=True)
if legacy.exists():
    if identity(legacy) != expected: raise SystemExit('Different app occupies legacy path: '+str(legacy))
    if target.exists(): raise SystemExit('Both old and new bundles exist; resolve this with backups first')
previous = legacy if legacy.exists() else target
if target.exists() and identity(target) != expected:
    raise SystemExit('Refusing to replace a different app at '+str(target))
if target.exists() and digest(source) == digest(target):
    print('Already installed and byte-identical: '+str(target))
else:
    # Preserve each previous version once; re-running does not duplicate backups.
    if previous.exists():
        backup = root/'recovery'/'install-backups'/(name+'-'+digest(previous)[:16]+'.zip')
        backup.parent.mkdir(parents=True,exist_ok=True)
        if not backup.exists(): subprocess.run(['ditto','-c','-k','--keepParent',str(previous),str(backup)],check=True)
        print('Recoverable original: '+str(backup))
    executable = str(previous/'Contents/MacOS'/('Caffeine' if previous == legacy else name))
    for line in subprocess.check_output(['ps','-axo','pid=,comm='],text=True).splitlines():
        parts = line.strip().split(None,1)
        if len(parts) != 2 or parts[1] != executable: continue
        pid = int(parts[0])
        if subprocess.check_output(['ps','-p',str(pid),'-o','comm='],text=True).strip() != executable: continue
        os.kill(pid,signal.SIGTERM)
        for _ in range(30):
            try: os.kill(pid,0)
            except ProcessLookupError: break
            time.sleep(.1)
        else: raise SystemExit('App did not quit; installation stopped')
    # Copy atomically into place; retain the old directory in the workspace for rollback.
    temporary = location/('.'+name+'.installing-'+str(os.getpid())+'.app')
    subprocess.run(['ditto',str(source),str(temporary)],check=True)
    subprocess.run(['codesign','--verify','--strict',str(temporary)],check=True)
    old = None
    if previous.exists():
        old = root/'recovery'/'install-backups'/(name+'-before-install-'+time.strftime('%Y%m%d-%H%M%S')+'-'+str(os.getpid())+'.app')
        previous.rename(old)
    try: temporary.rename(target)
    except Exception:
        if old is not None: old.rename(previous)
        raise
    assert digest(source) == digest(target), 'Installed bytes differ'
    print('Installed and verified: '+str(target))
# Launch the verified bundle; the shell then reconciles configured login startup.
subprocess.run(['open',str(target)],check=True)
executable = str(target/'Contents/MacOS'/name)
for _ in range(30):
    paths = subprocess.check_output(['ps','-axo','comm='],text=True).splitlines()
    if executable in [path.strip() for path in paths]:
        print('Running verified installation: '+str(target))
        break
    time.sleep(.1)
else: raise SystemExit('Installed successfully, but no process launched from '+str(target)+'. Quit any other copy before reopening.')
PY
  if [[ "$LOGIN" == true || -f "$HOME/Library/LaunchAgents/personal.harinaralasetty.Caffeine.login.plist" ]]; then
    CAFFEINATE_UI_INSTALL_DIR="$INSTALL_DIR" "$ROOT_DIR/script/login_items.sh" enable "$APP"
  fi
done

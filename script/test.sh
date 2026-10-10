#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_MODE="${1:-full}"
case "$CHECK_MODE" in full|--no-display) ;; *) echo 'Usage: test.sh [--no-display]' >&2; exit 2;; esac
# Some Command Line Tools versions ship TestingMacros but omit its search path.
TOOLCHAIN="$(xcode-select -p)"
MACROS="$TOOLCHAIN/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
EXTRA=()
if [[ -f "$MACROS" ]]; then
  EXTRA=(-Xswiftc -load-plugin-library -Xswiftc "$MACROS")
fi
if [[ "$CHECK_MODE" == --no-display ]]; then
  EXTRA+=(--skip realCLIFlagsExpiryAndMultipleProcesses)
fi
swift test --jobs 2 "${EXTRA[@]}"
# This mode tests real system-only assertions without launching an app or
# running the packaged self-test, which explicitly acquires display assertions.
[[ "$CHECK_MODE" != --no-display ]] || exit 0
./script/build_and_run.sh CaffeinateUI --build-only
./"dist/Caffeinate UI.app/Contents/MacOS/CaffeinateUI" --self-test

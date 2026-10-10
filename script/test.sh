#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Some Command Line Tools versions ship TestingMacros but omit its search path.
TOOLCHAIN="$(xcode-select -p)"
MACROS="$TOOLCHAIN/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
EXTRA=()
if [[ -f "$MACROS" ]]; then
  EXTRA=(-Xswiftc -load-plugin-library -Xswiftc "$MACROS")
fi
swift test --jobs 2 "${EXTRA[@]}"
./script/build_and_run.sh Caffeine --build-only
./dist/Caffeine.app/Contents/MacOS/Caffeine --self-test

# MicMute

The existing implementation and icons were adopted, preserving normal microphone behavior and settings. A small bug fix pins each toggle to one input device and refuses the operation if the default microphone changes before the write. The original installed bundle is archived under the root `recovery/` directory before replacement. Original source is retained at `~/Documents/Codex/2026-09-29/build-macos-apps-plugin-build-macos`.

Click the status icon to toggle the default input device's hardware mute. Right-click to view its current state and Quit. A one-second read-only refresh follows external changes. Some devices lack a writable hardware mute control, in which case the app reports the limitation.

Build using the root script. Safe logic checks run with `python3 script/test_micmute.py`: the current source is compiled against fake audio APIs, so it cannot touch real audio. Read the actual device state without changing it with:

```sh
swift MicMute/Tests/ReadAudioState.swift
```

The optional hardware check performs a real toggle and restores the original device's mute state, even after a failed check. It refuses to write when an input-capable audio device is active or unreadable. Run it only when no call or recording is in progress:

```sh
swiftc MicMute/Sources/Services/MicrophoneMuteService.swift \
  MicMute/Tests/HardwareToggleCheck.swift -o /tmp/micmute-hardware-check
/tmp/micmute-hardware-check --confirm-idle
```

A skipped check exits with status 2; a passed check exits with status 0. Normal tests never change hardware state. Visual menu checks and a future login test remain separate from automated tests.

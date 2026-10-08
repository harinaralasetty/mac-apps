# MicMute

The existing implementation and icons were adopted without changing microphone behavior or settings. The original installed `/Applications/MicMute.app` remains in place; its executable and resource hashes were checked. Original source is retained at `~/Documents/Codex/2026-09-29/build-macos-apps-plugin-build-macos`.

Click the status icon to toggle the default input device's hardware mute. Right-click to view its current state and Quit. A one-second read-only refresh follows external changes. Some devices lack a writable hardware mute control, in which case the app reports the limitation.

Build using the root script. Safe logic checks run with `python3 script/test_micmute.py`: the current source is compiled against fake audio APIs, so it cannot touch real audio. Read the actual device state without changing it with:

```sh
swift MicMute/Tests/ReadAudioState.swift
```

A real toggle test must wait until no call/recording is active. Read and record the original mute state; toggle once, confirm the device and menu state, then restore the original state and verify it. Do not count fake-backend tests as proof of the hardware transition.

# MicMute: microphone mute from the macOS menu bar

**MicMute** lets you toggle your Mac's default input device's hardware mute with one click and see whether that microphone is live, muted or unavailable. It is a native Swift and AppKit utility for macOS 13 or later.

## Install MicMute

Follow the [source installation requirements](../README.md#requirements), then run this command from the repository root:

```sh
./script/install.sh MicMute
```

To start MicMute at login, use `./script/install.sh MicMute --login`. See [installation locations, updates and recovery](../README.md#install-from-source) for user-only installation and rollback options.

## Mute and check your microphone

- **Left-click** the microphone icon to toggle the default input device's hardware mute.
- **Right-click** to view its current state and Quit.
- A one-second read-only refresh updates the icon after external changes.

MicMute requires a microphone with a writable Core Audio mute control. If the device has no control, cannot be read or cannot be changed, the app reports the limitation. It verifies the mute state after a write and reports unconfirmed changes.

Each toggle stays on one input device. If the default microphone changes before the write check, MicMute refuses the operation and asks you to try again. The state shown is the device's hardware mute state; it does not establish the mute state of every calling or recording app.

## Verify microphone behavior

The [safe logic checks](../script/test_micmute.py) compile the service against fake audio APIs and cannot touch real audio:

```sh
python3 script/test_micmute.py
```

Read the actual device state without changing it:

```sh
swift MicMute/Tests/ReadAudioState.swift
```

### Optional hardware toggle check

The [hardware check](Tests/HardwareToggleCheck.swift) performs a real toggle and attempts to restore the original device's mute state, including after a failed check. It refuses to write when an input-capable audio device is active or unreadable. Run it only when no call or recording is in progress:

```sh
swiftc MicMute/Sources/Services/MicrophoneMuteService.swift \
  MicMute/Tests/HardwareToggleCheck.swift -o /tmp/micmute-hardware-check
/tmp/micmute-hardware-check --confirm-idle
```

A skipped check exits with status 2; a passed check exits with status 0. Review any reported restoration failure before resuming microphone use. Normal tests never change hardware state. Visual menu checks and an actual login test remain separate from automated tests.

See [Caffeine's independent system and display sleep controls](../Caffeine/README.md) for the other utility in this repository.

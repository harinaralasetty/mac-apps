# MicMute and Caffeine: macOS menu bar utilities

Mute your default microphone or keep your Mac awake from the menu bar. **MicMute** controls a supported microphone's hardware mute; **Caffeine** prevents system or display idle sleep with independent controls. Both are native Swift and AppKit apps with no third-party package dependencies.

| App | Use it to | Main controls | Important limitation |
| --- | --- | --- | --- |
| [MicMute: microphone mute for Mac](MicMute/README.md) | Toggle the default input device's hardware mute and see its state | Left-click to toggle; right-click for status and Quit | The microphone must expose a writable mute control |
| [Caffeine: keep your Mac awake](Caffeine/README.md) | Prevent system or display idle sleep and inspect other sleep assertions | Separate system/display switches; uninterrupted timer and badges; saved choices return after relaunch | Lid closure, low battery or forced sleep can override idle-sleep prevention |

## Requirements

- macOS 13 or later to run the apps.
- A compatible Apple Swift 6 toolchain to build from source, supplied by Xcode or Xcode Command Line Tools. The [Swift package](Package.swift) declares tools version 6.0; use a current toolchain that supports the source syntax.
- Git and Python 3 for the scripts. Tests on newer Command Line Tools may require macOS 14 or later.
- Write access to the installation directory. The installer does not request administrator privileges.

Install Apple's Command Line Tools with `xcode-select --install` if needed. Check the selected toolchain with `xcode-select -p` and `swift --version`.

## Install from source

Clone the repository, then run **one** installer command for the apps you want. The [installer](script/install.sh) builds, verifies, installs and opens the selected apps.

```sh
git clone https://github.com/harinaralasetty/mac-apps.git
cd mac-apps
./script/install.sh MicMute
```

Other choices, run from the repository root:

```sh
./script/install.sh Caffeine          # Caffeine only
./script/install.sh MicMute Caffeine  # Both; also the default with no app names
./script/install.sh Caffeine --login  # Caffeine with startup at login
./script/install.sh --login           # Both with startup at login
```

Apps are installed in `/Applications` by default. For a user-only location:

```sh
MAC_APPS_INSTALL_DIR="$HOME/Applications" ./script/install.sh Caffeine --login
```

Open the installed app from Finder or Launchpad. For example, with the default location:

```sh
open /Applications/MicMute.app
open /Applications/Caffeine.app
```

Local bundles are ad hoc signed. The scripts verify bundle signatures; this is separate from Developer ID signing or notarization.

### Updating and recovery

Re-running the installer skips replacement of byte-identical bundles. Before replacing an older version, it saves a ZIP in `recovery/install-backups/` and moves the old bundle to your Trash. It quits only the selected installed app. Unselected apps and external sleep assertions are untouched; installation never runs a hardware microphone test.

To restore a previous bundle, quit that app, keep the current bundle if needed, then restore the matching `.app` from Trash or extract its backup ZIP and place it in the installation directory. Reopen it from that location.

If moving an app with existing startup registration, first disable its old registration, then reinstall at the new location with `--login`:

```sh
./script/login_items.sh disable Caffeine
MAC_APPS_INSTALL_DIR="$HOME/Applications" ./script/install.sh Caffeine --login
```

## Start at login

The [login startup script](script/login_items.sh) uses per-user LaunchAgents to open installed apps once in an Aqua login session. It has no KeepAlive loop, privileged helper or duplicate SMAppService registration.

```sh
./script/login_items.sh enable         # Both installed apps
./script/login_items.sh status         # Read existing registration
./script/login_items.sh disable Caffeine
```

Disabling startup does not quit the running app. The installer records the selected location. Registration checks do not prove that a future login will launch the app.

## Build and verify

Run these commands from the repository root:

```sh
./script/build_and_run.sh Caffeine --build-only
./script/build_and_run.sh MicMute --build-only
./script/test.sh
```

The [build script](script/build_and_run.sh) writes bundles to `dist/`. `--build-only` does not stop or launch apps. Running the script without arguments builds and launches the staging Caffeine bundle; it does not replace installed apps. Run mode stops only instances at its own staging path. Avoid launching staging MicMute alongside an installed copy.

The [test script](script/test.sh) runs Caffeine assertion, timer and award logic tests, twelve MicMute fake-backend checks and a real IOKit assertion self-test. It locates the shipped Swift Testing macro plugin when required by Command Line Tools. Tests do not write microphone state or stop external processes. Passing tests does not establish visual menu behavior, compatibility with every microphone or successful startup at a real login.

See [MicMute behavior and optional hardware verification](MicMute/README.md#verify-microphone-behavior) and [Caffeine manual UI verification](Caffeine/README.md#verify-the-menu-and-sleep-assertions) for checks beyond the automated suite.

## Support and maintenance

Maintained by [Hari Naralasetty](https://github.com/harinaralasetty). Report reproducible problems through [mac-apps issues](https://github.com/harinaralasetty/mac-apps/issues), including the app, macOS version, Swift version for build failures, and relevant error text.

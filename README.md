# Personal Mac apps

Native, dependency-free menu-bar utilities built with Swift and AppKit. Source is organized into `MicMute/` and `Caffeine/`; one root Swift package and build script serve both apps. Apps require macOS 13+. Tests on newer Command Line Tools may require macOS 14+.

## Use

- **MicMute:** open `/Applications/MicMute.app`. Left-click the microphone to toggle the default input device's hardware mute; right-click for status and Quit. Some microphones do not expose a writable mute control. [Details](MicMute/README.md).
- **Caffeine:** open `/Applications/Caffeine.app`. Steam indicates its own system or display assertion; a plain cup means its own assertions are off. System and display controls are independent. Saved choices return after relaunch. [Details](Caffeine/README.md).

## Install one app or a set

Install Apple's Xcode Command Line Tools (`xcode-select --install`) if needed, then clone this repository. These commands build from source, verify the bundles, install only the selected apps and open them:

```sh
git clone https://github.com/harinaralasetty/mac-apps.git
cd mac-apps
./script/install.sh MicMute                 # MicMute only
./script/install.sh Caffeine                # Caffeine only
./script/install.sh MicMute Caffeine        # Both; also the default with no app names
./script/install.sh Caffeine --login        # Only Caffeine, plus start at login
./script/install.sh --login                 # Both, plus start at login
```

Apps go to `/Applications` by default. For a user-only location, use `MAC_APPS_INSTALL_DIR="$HOME/Applications" ./script/install.sh Caffeine --login`. No administrator privilege is requested. If you relocate an app with existing startup registration, first run `./script/login_items.sh disable Caffeine`, then install it in the new location with `--login`.

Re-running the installer skips replacement of byte-identical bundles. Before replacing an older version, it saves a ZIP under `recovery/install-backups/` and moves the old bundle to Trash; it quits only the selected installed app. Unselected apps and external sleep assertions are untouched. Hardware microphone testing is never part of installation.

## Build and verify

```sh
./script/build_and_run.sh Caffeine --build-only
./script/build_and_run.sh MicMute --build-only
./script/test.sh
./script/login_items.sh status
```

Build output is in `dist/`. Local bundles are ad hoc signed. The default Run command launches the staging Caffeine bundle; it does not replace installed apps. `--build-only` never stops or launches apps. The script stops only instances running from its own staging path. Do not launch a staging MicMute alongside an installed instance.

`test.sh` runs six Caffeine logic tests, twelve MicMute fake-backend checks and a real IOKit assertion test. It explicitly locates the shipped Swift Testing macro plugin when required by Command Line Tools. Tests neither write microphone state nor stop external processes. Passing tests do not establish visual menu behavior or a real login test.

## Start at login

```sh
./script/login_items.sh enable
./script/login_items.sh status
# Optional: disable one startup registration without quitting the app
./script/login_items.sh disable Caffeine
```

Supported per-user LaunchAgents open the installed apps once in an Aqua login session. There is no KeepAlive loop, privileged helper or duplicated SMAppService registration. Registration can be verified without logging out. The installer records the selected location; the status command reads existing registration without changing it.

## Recovery and publication

MicMute's original installed bundle is archived in `recovery/`, and its original source folder is retained. The adopted implementation includes one small fix that keeps each mute operation on the same microphone when the default input changes. The original source repository, and both earlier combined-project repositories, had no commits at adoption; no existing commit history was rewritten. The canonical project is this directory. Recovery material and machine-specific evidence are excluded from Git, along with build output, caches and credential files.

Repository: [harinaralasetty/mac-apps](https://github.com/harinaralasetty/mac-apps). Publication uses the verified personal GitHub connector; the machine's CLI work-account authentication is unchanged.

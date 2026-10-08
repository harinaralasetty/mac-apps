# Personal Mac apps

Native, dependency-free menu-bar utilities built with Swift and AppKit. Source is organized into `MicMute/` and `Caffeine/`; one root Swift package and build script serve both apps. Apps require macOS 13+. Tests on newer Command Line Tools may require macOS 14+.

## Use

- **MicMute:** open `/Applications/MicMute.app`. Left-click the microphone to toggle the default input device's hardware mute; right-click for status and Quit. Some microphones do not expose a writable mute control. [Details](MicMute/README.md).
- **Caffeine:** open `/Applications/Caffeine.app`. Steam indicates its own system or display assertion; a plain cup means its own assertions are off. The system switch has two display options: keep it awake or allow it to sleep. Saved choices return after relaunch. [Details](Caffeine/README.md).

## Build and verify

```sh
./script/build_and_run.sh Caffeine --build-only
./script/build_and_run.sh MicMute --build-only
./script/test.sh
./script/login_items.sh status
```

Build output is in `dist/`. Local bundles are ad hoc signed. The default Run command launches the staging Caffeine bundle; it does not replace installed apps. `--build-only` never stops or launches apps. The script stops only instances running from its own staging path. Do not launch a staging MicMute alongside an installed instance.

`test.sh` runs seven Caffeine logic tests, eleven MicMute fake-backend checks and a real IOKit assertion test. It explicitly locates the shipped Swift Testing macro plugin when required by Command Line Tools. Tests neither write microphone state nor stop external processes. Passing tests do not establish visual menu behavior or a real login test.

## Start at login

```sh
./script/login_items.sh enable
./script/login_items.sh status
# Optional: disable one startup registration without quitting the app
./script/login_items.sh disable Caffeine
```

Supported per-user LaunchAgents open the installed apps once in an Aqua login session. There is no KeepAlive loop, privileged helper or duplicated SMAppService registration. Registration can be verified without logging out. After moving an installed app, update this script's app location before re-enabling startup.

## Recovery and publication

MicMute's installed bundle and original sources are preserved. The original source repository, and both earlier combined-project repositories, had no commits at adoption; no existing commit history was rewritten. The canonical project is this directory. Recovery material and machine-specific evidence are excluded from Git, along with build output, caches and credential files.

Repository: [harinaralasetty/mac-apps](https://github.com/harinaralasetty/mac-apps). Publication uses the verified personal GitHub connector; the machine's CLI work-account authentication is unchanged.

# Caffeine for macOS

<img src="Caffeine/Resources/AppIcon.png" alt="Caffeine app logo: a steaming white coffee cup on a warm copper background" width="160" height="160">

A native menu-bar utility to keep your Mac awake, follow `caffeinate` CLI sessions, and earn twelve coffee awards. Caffeine uses Swift, AppKit, SwiftUI and IOKit with no third-party package dependencies. Current source version: **1.3 (build 4)**.

- Control system and display idle sleep independently.
- See a session timer for app-owned and qualifying CLI assertions.
- Recover earlier time from a still-running CLI session, counting overlaps once.
- Open a resizable Awards window: locked artwork is grey, earned artwork is full colour, and earned badges persist.

![Actual Caffeine Awards window showing five full-colour earned badges and a grey locked three-day milestone](docs/screenshots/awards.jpg)

Actual installed 1.3 app, captured on 10 October 2026. Five awards came from a qualifying CLI session of roughly 2 days 14 hours. This elapsed time may include system sleep; the screenshot is not an isolated demonstration or proof of continuous awake time. Only app content is shown.

## Requirements

The app declares **macOS 13 or later**. Build with a compatible **Swift 6** toolchain from Xcode or Apple Command Line Tools, plus Git and Python 3 for scripts. The automated suite has been run on this Mac; test-framework compatibility on macOS 13 and other machines is not established. Newer Swift Testing libraries may require macOS 14 or later.

Check your toolchain with `xcode-select -p` and `swift --version`. Local bundles are ad hoc signed and verified by the scripts; this repository does not provide a notarized release or App Store distribution.

## Install from source

```sh
git clone https://github.com/harinaralasetty/caffeine.git
cd caffeine
./script/install.sh Caffeine
```

This checkout builds Caffeine only. The installer builds, verifies, installs into `/Applications` and opens Caffeine. It needs write access to the destination and does not elevate privileges. For a user installation:

```sh
CAFFEINE_INSTALL_DIR="$HOME/Applications" ./script/install.sh Caffeine
open "$HOME/Applications/Caffeine.app"
```

Re-running skips byte-identical bundles. Updates preserve a ZIP and the prior bundle in `recovery/install-backups/` in the checkout, then verify the installed bytes. To roll back, quit Caffeine and restore the matching backup bundle to the same install path. Backups and build output are ignored by Git.

Optional login startup uses a per-user LaunchAgent, without a KeepAlive loop:

```sh
./script/install.sh Caffeine --login
./script/login_items.sh status Caffeine
./script/login_items.sh disable Caffeine
```

Disabling startup does not quit Caffeine. When moving installations, disable the old registration before installing at the new path with `--login`. A registration check does not establish success at a future login.

## Use the menu

| Control | Behavior |
| --- | --- |
| Turn On | Enables system idle-sleep prevention |
| Keep System Awake | Toggles the app's system assertion |
| Keep Display Awake | Toggles the app's display assertion independently |
| Turn Off | Releases only Caffeine-owned assertions |
| CLI session / Awake streak | Shows current elapsed time |
| Show Awards… | Opens or raises one retained native Awards window |
| Other Sleep Assertions | Explains other active system/display assertions |

A steaming cup means Caffeine or qualifying CLI activity is active. A plain cup means neither is active. App choices persist and restore on launch; assertion IDs are always acquired afresh. Turning Caffeine off never stops external CLI processes. Lid closure, low battery, forced sleep and macOS power policy can override idle-sleep prevention.

## Timer and awards

![Closeup of the actual CLI session timer and matching award progress, including the sleep caveat](docs/screenshots/timer.jpg)

Caffeine samples qualifying CLI assertions once per second. System idle-sleep (`-i` or default) and display idle-sleep (`-d`) count. Timed `-t` and watched-process `-w` sessions stop qualifying when their assertions expire. User-active `-u`, disk-only `-m`, and unrelated apps do not earn awards. `-s` counts only on AC power and receives no historical credit by itself because earlier AC conditions are unknown.

A currently active assertion with a macOS start timestamp and global ID can recover its earlier duration, **including possible sleep**. That earlier time counts toward awards. The app reconciles one continuous interval by taking elapsed coverage, not by adding simultaneous sessions. Persisted interval claims match both identity and start timestamp; previously observed overlaps survive relaunch while an associated assertion is still active. Repeated opens, polling and relaunches do not multiply time or duplicate earned IDs. A restarted, nonoverlapping CLI identity starts a fresh interval. Closed process history is not restored. Missing metadata falls back to time observed by the app; future dates receive no earlier credit.

App-only progress resets when no qualifying activity remains, on quit/relaunch, or system sleep. A still-running CLI session can recover its interval after relaunch or sleep. Calendar changes do not advance an already anchored interval; a detected clock discontinuity prevents a new historical anchor. Display sleep and screen locking do not reset app-only progress. Earned awards remain saved, and no unlock dates are fabricated.

| Award | Session threshold |
| --- | --- |
| First Sip | 5 minutes |
| Espresso Yourself | 1 hour |
| Just One More Cup | 4 hours |
| The Daily Grind | 8 hours |
| Certified All-Nighter | 24 hours |
| Decaf Is a Myth | 3 days |
| Sleep Is a Rumor | 7 days |
| Bean There, Done That | 14 days |
| Your Mac Is Legally a Café | 30 days |
| Roast Level: Critical | 60 days |
| Legally an Espresso Machine | 90 days |
| Caffeine Overdose | 365 days |

A day is 24 hours. The [badge catalog](Caffeine/Resources/Badges/catalog.json) defines ordered thresholds and artwork; the [badge gallery](Caffeine/Resources/Badges/README.md) shows all twelve images.

## Build and test

```sh
./script/build_and_run.sh Caffeine --build-only
./script/test.sh
python3 script/audit_source.py
```

The build creates `dist/Caffeine.app`. Build-only does not launch or quit apps. The test script runs 22 Swift tests and a packaged self-test: real assertion acquisition/release, twenty ownership cycles, image decoding, simulated clocks, persistence, CLI overlap/restart and real test-owned CLI expiry. Tests use isolated defaults and never advance real award storage or terminate existing CLI processes.

See the [architecture and contribution guide](ARCHITECTURE.md) for the file map, invariants and diagnostic commands. Real system sleep, login-cycle and AC/battery switching remain manual checks; do them only when ongoing work can safely pause. Automated tests do not certify every macOS version or hardware configuration.

## Privacy and support

The app has no network client, account, telemetry service or cloud sync code. It reads local power-assertion metadata and saves app choices, earned IDs and CLI interval claims in local UserDefaults. Screenshots in this repository contain app UI only. Build/install scripts use local tools; cloning and pushing Git contact GitHub.

Maintained by [Hari Naralasetty](https://github.com/harinaralasetty). Report reproducible issues through [Caffeine repository issues](https://github.com/harinaralasetty/caffeine/issues), including macOS version, build/toolchain version, relevant errors and whether app-owned or CLI activity was involved. Review screenshots/logs for private information before posting.

# Caffeine: keep your Mac awake from the menu bar

**Caffeine** prevents system or display idle sleep with separate menu bar controls. It shows which sleep assertions it owns and which other apps also keep your Mac awake. This native Swift and AppKit utility requires macOS 13 or later.

## Install Caffeine

Follow the [source installation requirements](../README.md#requirements), then run this command from the repository root:

```sh
./script/install.sh Caffeine
```

To start Caffeine at login, use `./script/install.sh Caffeine --login`. See [installation locations, updates and recovery](../README.md#install-from-source) for user-only installation and rollback options.

## Control system and display idle sleep

Click the cup to open its menu:

| Control or indicator | Behavior |
| --- | --- |
| **Turn On** | Enables system idle-sleep prevention; leaves the display choice as it is |
| **Keep System Awake** | Toggles system idle-sleep prevention independently |
| **Keep Display Awake** | Toggles display idle-sleep prevention independently |
| **Turn Off** | Releases both of Caffeine's assertions |
| Steaming cup | Caffeine owns at least one system or display assertion |
| Plain cup | Caffeine owns no assertions |
| **Other Sleep Assertions** | Lists other assertion owners and details |

Turning Caffeine off does not guarantee that your Mac will sleep: another app or an external `caffeinate` process may still prevent it. Display assertions may also indirectly keep the system awake under macOS policy. Lid closure, low battery, forced sleep and other macOS or hardware conditions can override idle-sleep prevention.

## Uninterrupted timer and awards

The menu shows **Awake streak** as `HH:MM:SS` (plus days for longer sessions) and an **Awards** submenu with twelve badge images. A checkmark means the badge has been earned; hover over an unearned badge for its requirement. No automatic celebration alerts appear.

The timer counts one uninterrupted session while Caffeine owns at least one system or display assertion. Switching between controls preserves the streak if one remains active. Turning both off, quitting/relaunching, or system sleep resets it. Display sleep and screen locking do not reset it. External assertions cannot advance Caffeine's timer. Restored awake preferences start a fresh session after relaunch.

Earned badges persist locally in UserDefaults across sessions. Time is measured using system uptime, so adjusting the calendar clock cannot fast-forward awards. System sleep/wake is observed through [Apple's workspace notifications](https://developer.apple.com/documentation/appkit/nsworkspace/willsleepnotification); sleep itself is not credited. A day is 24 hours.

| Uninterrupted time | Award |
| --- | --- |
| 5 minutes | First Sip |
| 1 hour | Espresso Yourself |
| 4 hours | Just One More Cup |
| 8 hours | The Daily Grind |
| 24 hours | Certified All-Nighter |
| 3 days | Decaf Is a Myth |
| 7 days | Sleep Is a Rumor |
| 14 days | Bean There, Done That |
| 30 days | Your Mac Is Legally a Café |
| 60 days | Roast Level: Critical |
| 90 days | Legally an Espresso Machine |
| 365 days | Caffeine Overdose |

The [badge catalog](Resources/Badges/catalog.json) is the authoritative source for names, thresholds and image filenames. The [artwork preview](Resources/Badges/preview.html) can be opened locally. The transparent PNG artwork was generated with OpenAI's image generation tool; original prompts are included alongside it.

## Saved choices and assertion ownership

Successful system and display choices are stored independently in UserDefaults. Quit releases Caffeine's own assertions while preserving those choices; relaunch restores them. Assertion IDs are never persisted. A failed action cannot claim success or erase the saved choice. There is one GUI instance per bundle identifier.

Caffeine uses Apple's `IOPMAssertionCreateWithName`, `IOPMAssertionRelease` and `IOPMCopyAssertionsByProcess`. It does not launch a child `caffeinate` process or use process-wide kill commands. Networking, screen locking and security settings remain unchanged. See the [power assertion implementation](Core/PowerAssertions.swift) and [controller logic](Core/AwakeController.swift).

## Verify the menu and sleep assertions

The [shared build and test commands](../README.md#build-and-verify) cover logic and an IOKit assertion self-test. Use this manual sequence to check visual behavior; it changes awake settings and their saved choices:

1. Starting with both controls off, select **Turn On**: steam appears, system is checked, display is unchecked and Caffeine owns one system assertion.
2. Enable display: both are checked and Caffeine owns two assertions.
3. Disable system: only display remains checked and steam stays visible.
4. Select **Turn Off**: the cup is plain, both controls are unchecked and Caffeine owns no assertions. External assertions remain.
5. Enable display alone, Quit and relaunch: the display choice and assertion return with no duplicate GUI process. Finish with **Turn Off** if that is the desired saved state.
6. Compare the menu with `pmset -g assertions`. Check the Finder application icon and off/on menu icons visually.

For the timer, leave the menu open for a few seconds and confirm it advances. Toggle one mode while the other remains on: the timer must continue. Turn both off and back on: it starts at zero. Leave Caffeine active for five minutes: First Sip becomes checked, survives quit/relaunch, and the timer restarts. Long milestones and failure paths are checked with a simulated clock, not a real year-long run. A real system sleep/wake test should be done only when ongoing work can safely sleep.

Login registration is a separate check from startup at an actual future login.

## Rebuild the application icon

The menu bar cup is template artwork drawn with AppKit. The application icon is local vector artwork generated by the [icon script](../script/generate_icon.swift); it uses no downloaded components. From the repository root:

```sh
swift script/generate_icon.swift Caffeine/Resources
iconutil -c icns Caffeine/Resources/AppIcon.iconset -o Caffeine/Resources/AppIcon.icns
```

See [MicMute's microphone mute controls and device limitations](../MicMute/README.md) for the other utility in this repository.

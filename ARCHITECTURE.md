# Caffeine architecture and contribution guide

Start with the [README](README.md) for product behavior and supported commands. This guide maps the implementation for contributors and coding/retrieval agents. Package.swift declares CaffeineCore, the Caffeine executable and CaffeineCoreTests; there are no third-party dependencies.

## File map

| File | Responsibility |
| --- | --- |
| [CaffeineApp.swift](Caffeine/Sources/App/CaffeineApp.swift) | AppKit lifecycle, duplicate-instance check, reopen handling and diagnostics |
| [StatusBarController.swift](Caffeine/Sources/Support/StatusBarController.swift) | Menu actions, common-mode one-second polling, power/sleep notifications and UI updates |
| [AwardsWindowController.swift](Caffeine/Sources/Support/AwardsWindowController.swift) | Retained native window, SwiftUI cards, cached grayscale locked images |
| [CupIcon.swift](Caffeine/Sources/Support/CupIcon.swift) | App-owned steaming/plain status artwork |
| [AwakeController.swift](Caffeine/Core/AwakeController.swift) | Owned IDs, independent controls, filtered external CLI observations and interval reconciliation |
| [PowerAssertions.swift](Caffeine/Core/PowerAssertions.swift) | IOKit create/release, active assertion snapshots, power-source classification, CLI identity/start metadata |
| [AwakeSession.swift](Caffeine/Core/AwakeSession.swift) | Catalog validation, elapsed progress, threshold unlocks and earned-ID persistence |
| [CLIActivityClock.swift](Caffeine/Core/CLIActivityClock.swift) | Monotonic current CLI interval, recovered start, overlap continuity and persisted claims |
| [AwakePreferences.swift](Caffeine/Core/AwakePreferences.swift) | Saved independent control choices |
| [RuntimeCheck.swift](Caffeine/Sources/Support/RuntimeCheck.swift) | Isolated packaged assertion and native-view diagnostics |
| [Tests](Caffeine/Tests) | Failure, boundary, persistence, CLI identity/overlap/expiry and policy tests |
| [catalog.json](Caffeine/Resources/Badges/catalog.json) | Single ordered source for badge names, thresholds and image filenames |
| [script](script) | Build, install/recovery, optional login registration and verification tools |

## Invariants to preserve

- `AwakeController` releases only IDs returned by its backend. External CLI processes remain untouched.
- `isActive` means app-owned assertions; `isSessionActive` additionally includes qualifying CLI assertions. Control checkmarks describe owned state.
- Qualifying CLI assertions use the canonical caffeinate name and active system/display types. AC-only `PreventSystemSleep` is filtered on battery.
- Historical CLI progress is an interval, not an additive balance: `includeCLIInterval` extends coverage using `min(startedAt, now - seconds)`. Polling, multiple processes and relaunch must never sum the same interval twice.
- CLI recovery uses current `GlobalUniqueID` plus `AssertStartWhen`. Saved interval starts are considered only when that exact assertion is active. Observed overlaps can retain earlier coverage. Missing/invalid dates and clock discontinuities remain conservative.
- CLI elapsed time may include sleep by product policy. It is not a verified uninterrupted awake duration. App-only sleep resets progress.
- Earned IDs union into a set under `awards.earnedIDs.v1`; CLI claims use `awards.cliIntervals.v1`. Interval records are checkpointed on identity changes and at most once per minute during steady activity; recent inactive recovery records are bounded. Both use local UserDefaults only. App control preferences are separate.
- A disappearing/failed CLI snapshot must not earn a final unobserved boundary. Sleep/wake and assertion failures must preserve truthful owned state.
- Awards names, thresholds, order and approved PNG artwork come from the catalog. Do not invent unlock dates or change real awards for tests/screenshots.

## Validate a change

Run `./script/test.sh`, `python3 script/audit_source.py` and `git diff --check`. Use fake clocks for long thresholds and a unique UserDefaults suite with cleanup for persistence. Real CLI tests may terminate only Process instances they created. Build-only should not launch staging over an installed app.

The packaged isolated UI diagnostic is:

```sh
./script/build_and_run.sh Caffeine --build-only
open -W dist/Caffeine.app --args --awards-ui-check /tmp/caffeine-ui-check
```

It renders native views at 4:59 and 5:00 with in-memory progress and no real defaults. The `--self-test` path also avoids real award defaults. Normal launch restores real local choices/awards; `--show-awards` opens the live window. Verify live readability, grey/full-colour states, Close/reopen and CLI start/expiry separately. Do not force sleep/login or power-source changes during other ongoing work.

Some nested execution environments cannot run SwiftPM's manifest sandbox or register an AppKit process. Use an authorized native local executor. A per-command SwiftPM `--disable-sandbox` may be required there, with workspace cache paths; it is not a requirement for ordinary Mac builds and does not authorize changing host security settings. Tests on this Mac needed the shipped TestingMacros plugin; `script/test.sh` resolves its path.

## Repository scope and documentation

Current HEAD publishes Caffeine only; older commits are retained. Local ignored remnants of the former app and recovery backups are not part of current tracked contents. Keep the existing repository URL and published history unless a migration is separately authorized.

Keep README claims grounded in source and checks. Use readable Markdown, descriptive links and contextual image alt text. The documentation brief follows [Google's people-first content guidance](https://developers.google.com/search/docs/fundamentals/creating-helpful-content) and [W3C writing accessibility guidance](https://www.w3.org/WAI/tips/writing/), via the Prompts seo-optimise workflow. GitHub manages crawling/rendering; these editorial changes make no indexing, ranking or AI citation guarantees. Do not add website infrastructure or mandatory llms.txt for this repository.

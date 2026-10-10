# Homebrew distribution preparation

Status: local preparation only. No signed distributable release, tap or working Homebrew install command is published. Use the GitHub source repository as the homepage; a separate download website is unnecessary. No license has been chosen.

## Decisions and prerequisites

- Proposed maintainer tap name: `harinaralasetty/homebrew-tap`, cask token `caffeinate-ui` (authorized display name: Caffeinate UI). The official `caffeine` and `domzilla-caffeine` tokens already distribute other vendors' apps. A fully qualified tap token avoids pretending this is the official cask. Availability checked against official listings on 10 October 2026; recheck before publication.
- Current artifact: version 1.4/build 5, arm64-only, release-optimized compilation, ad hoc signature, no TeamIdentifier. It is a local build, not a trusted public release.
- Naming approved by Hari. The authorized rename uses Caffeinate UI.app and the caffeinate-ui repository; retain the existing bundle identifier and preferences. Initial recommendation: release-optimized Apple Silicon package. Intel/universal support needs a separately built and tested x86_64 slice; do not claim support from package minimum-version declarations. Confirm supported macOS versions on clean systems.
- Apple Developer membership status is unknown. Trusted distribution needs the owner's Developer ID Application signing identity/private key, hardened runtime with secure timestamp, and an authorized notarytool credential profile or App Store Connect API credential. The owner must provision these; never paste secrets into source, chat, or cask files. No enrollment or credentials have been configured.
- Choose a license before describing reuse/distribution rights. No license is inferred from public GitHub visibility.

## Build and immutable artifact

`./script/build_and_run.sh CaffeinateUI --release-build-only` compiles with SwiftPM's release configuration and stages only `dist/Caffeinate UI.app`. It does not install, launch, alter app identity, or advance awards. It still ad hoc signs for local verification; this command alone does not produce a public trusted artifact. The shared staging folder is replaced, so preserve any staged bundle needed for comparison first.

After signing and licensing prerequisites are settled:

1. Build from a clean, tagged commit with a fresh public version/build number. Verify resources, minimum OS, executable architectures (`lipo -archs`), and release optimization. Run unit tests and the packaged self-test before signing.
2. Sign the complete bundle with Developer ID Application, secure timestamp and hardened runtime; inspect required entitlements rather than adding broad ones. Verify with `codesign --verify --strict --verbose=2` and inspect signature/team/runtime flags.
3. Submit a ZIP containing the signed app via `xcrun notarytool submit ... --wait` using the owner's existing authorized credential profile. Inspect the accepted result/log; staple the ticket to the app with `xcrun stapler staple`, then validate the ticket. Repackage the stapled app with `ditto -c -k --keepParent`.
4. Assess the final quarantined app with Gatekeeper (`spctl --assess --type execute --verbose=2`) on a clean machine. Do not remove quarantine or use no-quarantine flags.
5. Hash the final archive, not the executable or pre-staple ZIP. Publish a tagged GitHub release asset only after checks pass, enable immutable releases before publishing, and verify immutability. Never replace bytes behind a released URL; corrections get a new version/tag.
6. Download the published asset anew and verify its exact SHA-256. Only then replace the required values in `homebrew/caffeinate-ui.rb.in` and create the chosen tap's `Casks/caffeinate-ui.rb`. The template deliberately supplies no guessed download URL, hash or install command.

## Collision and lifecycle checks

A distinct token does not prevent an app-path collision: the two official distributions use `/Applications/Caffeine.app`; this renamed app uses `/Applications/Caffeinate UI.app`. The template declares conflicts with the two official casks, but a manually installed bundle is not represented by those conflicts. Homebrew must refuse an occupied destination; never use force/adopt, rename the bundle, or overwrite another vendor's app automatically. The installed app and its preferences must stay untouched during Homebrew lifecycle tests. The separately authorized rename migrates this project's own old app with backup and identity verification. Choose any migration explicitly with backup and identity verification.

Use a clean test Mac or disposable VM with no existing Caffeinate UI bundle/defaults, standard Homebrew quarantine, and no automatic login hooks. Test the following after a real artifact and cask exist:

- `brew style` and strict online cask audit against the actual tap file; Ruby syntax alone is not a cask audit.
- Clean install/download checksum, signed identity, Gatekeeper first launch, all badges and native Awards window.
- Upgrade between two real release versions: quit gracefully, preserve earned IDs/interval claims and menu settings, verify new app bytes/version, then relaunch. Homebrew may require the user to quit the app; do not kill unrelated CLI sessions.
- Existing official-cask and manually installed-app collisions: fail safely without modifying either app.
- Ordinary uninstall: remove only the cask-managed application; preserve awards/preferences and leave CLI processes intact. No zap is included. Test any future optional destructive cleanup only with disposable defaults.

Do not install/uninstall on Hari's active Mac to simulate a clean system. No lifecycle test or Intel validation has been claimed yet.

## References

- [Homebrew cask fields, checksums, app artifacts and conflicts](https://docs.brew.sh/Cask-Cookbook)
- [Maintaining a custom tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Official caffeine token](https://formulae.brew.sh/cask/caffeine) and [domzilla-caffeine token](https://formulae.brew.sh/cask/domzilla-caffeine)
- [Apple notarization workflow](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub immutable releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

Exact caffeinate-ui token check: no matches in official cask or formula JSON catalogs on 10 October 2026. Public GitHub search found seven similarly named repositories, including narate/caffeinate-ui and yeusin/caffeinate-ui macOS menu-bar apps. This is not an exclusive global name or trademark clearance; fully qualify the own-tap token and describe the maintainer in the listing.

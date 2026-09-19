# Decisions

## 1. Continue Leader Key as Keywink

Date: 2026-09-19. Status: accepted; repository created. App rebranding completed by Decision 3 below.

Niklas selected **Keywink** and explicitly requested a fork of the original project under that name. The repository is [niklas-heer/Keywink](https://github.com/niklas-heer/Keywink), a GitHub fork of [mikker/LeaderKey](https://github.com/mikker/LeaderKey). Its initial default-branch baseline is [`16bcb307dcc5309fbc3a00fe398d913e1f7ddc51`](https://github.com/mikker/LeaderKey/commit/16bcb307dcc5309fbc3a00fe398d913e1f7ddc51).

Preserve upstream Git history, contributor attribution, and the existing MIT license. Develop the continuation under a distinct name, consistent with the [upstream maintainer's request](https://github.com/mikker/LeaderKey/issues/323#issuecomment-5152927484). This fork does not transfer control of upstream issues, pull requests, or releases.

The initial setup establishes the repository and its documentation. Application identifiers, configuration migration, signing, update feeds, and release automation still need separate implementation and verification before a Keywink release. The first proposed milestone is documented in the README; no blanket acceptance of the upstream feature backlog is implied.

## 2. Isolate tests before establishing the build baseline

Date: 2026-09-19. Status: implemented and verified.

The inherited configuration tests deleted the real default configuration directory. Changing a global UserDefaults variable per fixture also failed to redirect already-initialized Defaults keys. The app and defaults code used different XCTest detection markers, and a storyboard-created Sparkle controller started before the app's test guard.

Use one test-runtime detector for both XCTest environment markers and the XCTest runtime class. Tests receive an immutable process-private preferences suite and temporary default configuration path; configuration fixtures additionally inject their own directory accessors and fallback resolver. Start the updater programmatically after the test guard. Never perform configuration test cleanup against Application Support.

The baseline Debug build and all 36 tests passed on Xcode 26.6. Before/after file fingerprints confirmed the real Leader Key and Keywink configuration directories were unchanged. The local Xcode installation first required `xcodebuild -runFirstLaunch` to repair a missing DVTDownloads symbol; this was a machine setup issue, not an app defect.

Remove the inherited source-mutating formatting build phase and its approval-requiring formatting plug-in. Formatting is an explicit mise task, so compiling no longer rewrites source or requires trusting an unrelated build plug-in. This supersedes the initial unsafe-test warning; upstream PR 313 was not adopted as a presumed fix.

## 3. Separate Keywink's runtime identity and import explicitly

Date: 2026-09-19. Status: implemented under the authorized identity-migration milestone.

Ship `Keywink.app` with bundle identifier `de.niklas-heer.Keywink`, configuration under `~/Library/Application Support/Keywink`, and the `keywink://` URL scheme. Start Keywink's version sequence at `0.1.0` build `1`. Replace visible branding and icons; keep the inherited internal Xcode project, targets, scheme, source paths, and `Leader_Key` module to avoid unrelated source-path churn. Preserve upstream Git history, attribution, and license.

Do not automatically share or move Leader Key's preferences or files. An explicit settings import accepts an existing JSON configuration, validates it, backs up the destination, and copies the data without changing its source. Pending saves/loads must not overwrite the imported state. Activation shortcuts, preferences, and login registration are configured separately. Leader Key's URL scheme is not registered or handled.

Verification: all 47 tests pass, including import persistence/failure cases, pending-I/O handling, built bundle identity, URL parsing, and updater configuration. Debug and universal Intel/Apple Silicon Release builds pass. Real configuration fingerprints remain unchanged after tests.

This completes the runtime-identity portion left pending in Decision 1. The bundle identifier and migration mechanics are implementation choices within the requested milestone; they were not separately specified by the user.

## 4. Use mise with native macOS checks and local release preparation

Date: 2026-09-19. Status: implemented; public release and update service not activated.

The user explicitly selected mise for setup. Use it for native Xcode build/test tasks, explicit formatting, strict lint, and release preparation. Xcode supplies Swift and swift-format; the existing SwiftPM lockfile fixes app dependencies. CI pins Xcode 26.6 on macOS. AppKit and Xcode require native macOS coverage, so the usual Dagger preference would not replace this check. Fix the two inherited whitespace warnings with Xcode's formatter so CI can enforce strict, non-mutating lint.

Use Keywink's GitHub releases for future artifacts. The local release scripts create a fresh Developer ID archive, export, notarize, staple, verify, and package the app with a checksum. They do not tag, publish, upload to an upstream bucket, or auto-commit. Supply the Apple team/certificate and notary Keychain profile outside the repository. These external signing steps require maintainer setup before the first public release.

Remove the inherited Apple team, S3 uploader, appcast workflow, Sparkle key/feed, and checked-in Sparkle executables. Instantiate Sparkle only when a valid HTTPS feed and 32-byte public key are explicitly supplied through Keywink build settings. Until then, the app links to Keywink's release page. An independently hosted appcast, retained private key, and real signed-update test remain prerequisites before enabling updates. See [RELEASE.md](RELEASE.md) and [Sparkle's programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/).

## 5. Offer a fluid top-edge launcher

Date: 2026-09-19. Status: implemented design direction; visual refinement remains open.

Niklas disliked the centered square and proposed a top-oriented, more fluid launcher that follows the system theme and fits newer MacBook camera housings. A screenshot from another shell project served as visual inspiration, not a request to copy that project's functionality.

Implement **Top Edge** as the default for an unset theme preference. Keep existing themes and explicit selections. Use native macOS material, light/dark colors, a curved bridge below a detected notch, and a rounded floating fallback below the menu bar on ordinary displays. Keep shortcut hints within the wide panel; resize for each group and scroll large groups. Respect reduced motion and reduced transparency. The exact layout, name, and default are implementation choices within this requested direction.

Position against the selected display's current visible frame and camera safe-area information, including external monitors with nonzero or negative origins and side Docks. Bound the panel to that usable area. Guard animation completions so dismissing and reopening cannot close a new presentation.

Verification: all 51 tests and strict formatting pass, including geometry cases and native panel presentation/navigation/dismissal, config-replacement invalidation, and rapid dismiss/reopen behavior. Light and dark renders were inspected; the notch silhouette was also rendered with simulated camera geometry. This does not claim an end-to-end check on every physical notch/display configuration.

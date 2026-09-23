# Releasing Keywink

Keywink releases are prepared locally and uploaded to this repository's GitHub Releases. The repository does not contain signing credentials, publish artifacts automatically, or reuse the inherited Leader Key S3 bucket and appcast workflow.

The Xcode project, scheme, and targets are named `Keywink`. The shipped product is `Keywink.app`, with bundle identifier `de.niklas-heer.Keywink`.

## Prerequisites

- A current Xcode installation with the command line tools selected.
- Membership in an Apple Developer team.
- A `Developer ID Application` certificate in the login Keychain.
- App Store Connect API-key or Apple ID credentials stored as a `notarytool` Keychain profile. Create it interactively; do not put credentials in this repository:

  ```sh
  xcrun notarytool store-credentials keywink-notary
  ```

- `mise` for the documented task shortcuts. The scripts can also be run directly.

## Prepare a release

1. Start from a clean checkout and set an explicit version and monotonically increasing build number:

   ```sh
   bin/bump 0.1.0 1
   mise run check
   ```

   `mise run lint` checks the Swift source directories without changing them. Use the separate `mise run format` task when you intentionally want to rewrite those files.

   Review and commit the version change and all release content before continuing. `bin/release` refuses to submit a notarization request while tracked changes are staged or unstaged.

2. Export the signing configuration for this shell. The certificate name is optional when the standard name is correct:

   ```sh
   export KEYWINK_DEVELOPMENT_TEAM="YOUR_TEAM_ID"
   export KEYWINK_NOTARY_PROFILE="keywink-notary"
   export KEYWINK_SIGNING_IDENTITY="Developer ID Application: Your Name (YOUR_TEAM_ID)"
   ```

   Release builds enable Sparkle by default with the feed `https://github.com/niklas-heer/Keywink/releases/latest/download/appcast.xml` and the published Ed25519 public key; `bin/archive` forwards both to Xcode. Set `KEYWINK_UPDATE_FEED_URL=""` and `KEYWINK_UPDATE_PUBLIC_KEY=""` to build with updates disabled, or point them at another feed and key pair.

3. Prepare the signed and notarized artifact:

   ```sh
   mise run release
   ```

   `bin/release` creates `build/release/Keywink.xcarchive`, exports and verifies `Keywink.app`, submits a temporary ZIP to Apple, staples and validates the notarization ticket, and creates these local artifacts:

   ```text
   build/release/artifacts/Keywink-<version>-<build>.zip
   build/release/artifacts/Keywink-<version>-<build>.zip.sha256
   build/release/artifacts/appcast.xml
   ```

   The appcast lists this release only and is signed with the Sparkle key from the login Keychain (account `ed25519`, override with `KEYWINK_SPARKLE_ACCOUNT`). Installed apps follow the `latest/download` redirect, so each release replaces the feed and every older version updates straight to the newest one.

   The command stops if an archive or final artifact already exists. This avoids silently publishing a stale build. Move or remove the generated `build/release` directory before deliberately preparing the same version again.

   `mise run archive` is available when you only want to inspect a signed archive. It writes the same default archive path, so move or remove that standalone archive before running `mise run release`; the release task always creates a fresh archive and refuses to reuse an existing one.

4. Tag the released commit, push the tag, and create a GitHub release with the ZIP, checksum, appcast, and release notes. This is a deliberate manual step; the local task does not create a tag, commit, push, or publish a release. The appcast must be attached, or installed apps stop seeing updates.

   ```sh
   git tag -a v0.1.0 -m "Keywink 0.1.0"
   git push origin v0.1.0
   gh release create v0.1.0 \
     build/release/artifacts/Keywink-0.1.0-1.zip \
     build/release/artifacts/Keywink-0.1.0-1.zip.sha256 \
     build/release/artifacts/appcast.xml \
     --title "Keywink 0.1.0" \
     --notes-file build/release/notes-0.1.0.md
   ```

   The fork still carries the inherited upstream `v1.x` tags. GitHub marks the most recently created release as latest, so the lower Keywink version numbers do not affect which release is shown first.

## Interim ad-hoc releases

Until a Developer ID certificate and notary profile are available, `mise run release-adhoc` packages an ad-hoc signed build:

```text
build/release/artifacts/Keywink-<version>-<build>-adhoc.zip
build/release/artifacts/Keywink-<version>-<build>-adhoc.zip.sha256
```

The `-adhoc` suffix marks the artifact as not notarized. macOS blocks such apps on first launch with "Apple could not verify". The user opens the app once, then approves it in **System Settings → Privacy & Security → Open Anyway**, or removes the quarantine attribute before launching:

```sh
xattr -d com.apple.quarantine /Applications/Keywink.app
```

State this clearly in the release notes. Replace ad-hoc artifacts with notarized ones as soon as signing works; do not enable Sparkle for ad-hoc builds.

## Sparkle updates

Releases since 0.2.1 check `https://github.com/niklas-heer/Keywink/releases/latest/download/appcast.xml` and verify updates with the Ed25519 public key baked into the build. Keeping updates working requires:

- The Sparkle private key in the login Keychain of the release machine (`generate_keys`, account `ed25519`). One key signs updates for every app released from this machine. Keep an exported copy (`generate_keys -x <file>`) in a password manager, never in a repository. Losing the key means installed copies cannot verify any further update.
- Every GitHub release carrying a fresh `appcast.xml` asset. `bin/release` generates and verifies it.
- A `CFBundleVersion` higher than the previous release; `bin/bump` sets it.

Ad-hoc builds (`bin/release-adhoc`) and unconfigured local builds keep the updater disabled and show **Keywink Releases…** instead of **Check for Updates…**. The Sparkle tools come from the Swift Package Manager artifact of the resolved Sparkle version; the removed upstream binaries stay removed.

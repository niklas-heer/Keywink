# Releasing Keywink

Keywink releases are prepared locally and uploaded to this repository's GitHub Releases. The repository does not contain signing credentials, publish artifacts automatically, or reuse the inherited Leader Key S3 bucket and appcast workflow.

The Xcode project and scheme keep the inherited `Leader Key` name for now. The shipped product is `Keywink.app`, with bundle identifier `de.niklas-heer.Keywink`.

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

   Leave `KEYWINK_UPDATE_FEED_URL` and `KEYWINK_UPDATE_PUBLIC_KEY` unset to build with updates disabled. After the independent Sparkle feed is ready, export both values before creating the archive; `bin/archive` forwards them explicitly to Xcode:

   ```sh
   export KEYWINK_UPDATE_FEED_URL="https://example.com/keywink/appcast.xml"
   export KEYWINK_UPDATE_PUBLIC_KEY="BASE64_ED25519_PUBLIC_KEY"
   ```

3. Prepare the signed and notarized artifact:

   ```sh
   mise run release
   ```

   `bin/release` creates `build/release/Keywink.xcarchive`, exports and verifies `Keywink.app`, submits a temporary ZIP to Apple, staples and validates the notarization ticket, and creates these local artifacts:

   ```text
   build/release/artifacts/Keywink-<version>-<build>.zip
   build/release/artifacts/Keywink-<version>-<build>.zip.sha256
   ```

   The command stops if an archive or final artifact already exists. This avoids silently publishing a stale build. Move or remove the generated `build/release` directory before deliberately preparing the same version again.

   `mise run archive` is available when you only want to inspect a signed archive. It writes the same default archive path, so move or remove that standalone archive before running `mise run release`; the release task always creates a fresh archive and refuses to reuse an existing one.

4. Tag the released commit, push the tag, and create a GitHub release with the ZIP, checksum, and release notes. This is a deliberate manual step; the local task does not create a tag, commit, push, or publish a release.

   ```sh
   git tag -a v0.1.0 -m "Keywink 0.1.0"
   git push origin v0.1.0
   gh release create v0.1.0 \
     build/release/artifacts/Keywink-0.1.0-1.zip \
     build/release/artifacts/Keywink-0.1.0-1.zip.sha256 \
     --title "Keywink 0.1.0" \
     --notes-file build/release/notes-0.1.0.md
   ```

   The fork still carries the inherited upstream `v1.x` tags. GitHub marks the most recently created release as latest, so the lower Keywink version numbers do not affect which release is shown first.

## Sparkle updates

The app updater remains disabled until both `KEYWINK_UPDATE_FEED_URL` and `KEYWINK_UPDATE_PUBLIC_KEY` are configured at build time. The feed URL must use HTTPS, and the public key must be the valid base64-encoded 32-byte Ed25519 key generated for Keywink.

Before enabling updates:

1. Generate and securely retain a Keywink-specific Sparkle private key. Never commit it.
2. Choose a stable HTTPS location for the Keywink appcast. GitHub Pages or another static host can serve it independently of the GitHub release assets.
3. Use the Sparkle tools from the version resolved by Swift Package Manager to sign the release ZIP and generate the appcast. Do not restore the removed inherited binaries.
4. Configure the two build settings for release builds, verify a signed update from an older Keywink version, and document the feed's publishing and key-recovery process.

GitHub Releases are the intended artifact store. Sparkle's feed is separate metadata that points to those immutable release assets; enabling it does not require restoring the upstream S3 automation.

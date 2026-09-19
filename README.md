# Keywink

A native macOS command launcher with memorable key sequences, visual hints, and a focus on easy configuration.

Keywink is an independent fork of [Leader Key](https://github.com/mikker/LeaderKey), created by Mikkel Malmberg and its contributors. Their history and [MIT license](LICENSE) are preserved.

## Status

Keywink has its own application identity and local build/release preparation. There is no published Keywink release yet. Builds use the `Keywink.app` name, `de.niklas-heer.Keywink` bundle identifier, and `keywink://` URL scheme. Leader Key can remain installed alongside it.

The Xcode project, target, scheme, and Swift module retain their inherited names to keep this migration small. These internal names do not determine the installed app's identity.

## Development

Install Xcode with the macOS SDK, complete its first-launch setup, and install [mise](https://mise.jdx.dev/). Xcode provides Swift and the formatter; Swift Package Manager dependencies are locked in the project. No Homebrew packages are required to build.

```sh
mise trust
mise run build
mise run test
```

Tests use temporary configuration directories and an isolated preferences domain. `mise run format` explicitly formats source; builds do not rewrite files. See [AGENTS.md](AGENTS.md) for development guidance and [RELEASE.md](RELEASE.md) for signing, notarization, packaging, and update setup.

## Configure

Open Keywink's menu bar item, choose **Settings…**, and record the shortcut that opens the launcher. Add actions or groups in the configuration editor. Then press your shortcut followed by the keys in a sequence: for example, `o`, then `m` to open Messages.

**Top Edge** is the default launcher theme: a wide, native-material panel below the menu bar, with a curved bridge beneath the camera on supported MacBooks. Shortcut hints are built in, and the panel resizes as you navigate groups. It follows light/dark appearance and the system's reduced-motion/transparency settings. Choose **Settings → General → Theme → Top Edge** if you previously selected another theme; the original themes remain available.

Keywink stores `config.json` in `~/Library/Application Support/Keywink/`. Preferences, shortcuts, and launch-at-login registration belong to Keywink's bundle identity. Choose a different configuration directory in Advanced settings if needed.

### Import from Leader Key

In **Settings → General**, choose **Import Leader Key config…** and select the existing `config.json` (normally under `~/Library/Application Support/Leader Key/`). Review the replacement confirmation. Keywink validates the file, preserves a backup of its current configuration, and copies the selected configuration into its own directory. The original file remains unchanged.

Only the JSON configuration is imported. Record your activation shortcut and select other preferences in Keywink. Update any `leaderkey://` automation URLs to `keywink://`. Avoid assigning both running apps the same global shortcut.

## Automation

```sh
open 'keywink://activate'
open 'keywink://hide'
open 'keywink://reset'
open 'keywink://settings'
open 'keywink://about'
open 'keywink://config-reload'
open 'keywink://config-reveal'
open 'keywink://navigate?keys=a,b,c'
open 'keywink://navigate?keys=a,b,c&execute=false'
```

Unknown commands show the launcher. Keywink does not register or handle Leader Key's URL scheme.

## Releases and updates

Future downloads belong in [Keywink releases](https://github.com/niklas-heer/Keywink/releases). `brew install leader-key` installs the upstream app; there is no Keywink cask yet.

Automatic updates remain disabled until Keywink's own HTTPS appcast and EdDSA public key are configured. The inherited upstream update feed, signing key, Apple team, and publishing workflow are removed. Local release tasks prepare artifacts; publishing is a separate step. See [RELEASE.md](RELEASE.md).

## Contributing

Track work in [Keywink's issues](https://github.com/niklas-heer/Keywink/issues). [DECISIONS.md](DECISIONS.md) records the fork baseline and migration choices. Upstream fixes and editor/overlay improvements will be reviewed against a focused command-launcher scope.

## License

MIT. See [LICENSE](LICENSE).

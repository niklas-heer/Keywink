<p align="center">
  <img alt="Keywink app icon" src="docs/images/icon.png" width="128">
</p>

# Keywink

A native macOS command launcher driven by memorable key sequences. Press one shortcut, then type a few letters, and Keywink opens apps, URLs, folders, or runs commands. A compact on-screen guide shows what each key does, so you never have to memorise a shortcut table.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/key-guide-dark.png">
    <img alt="Keywink's Key Guide showing a root group of shortcuts" src="docs/images/key-guide-light.png" width="440">
  </picture>
</p>

Keywink is an independent fork of [Leader Key](https://github.com/mikker/LeaderKey) by Mikkel Malmberg and contributors. Their history and [MIT license](LICENSE) are preserved. Keywink has its own app identity, so it can run alongside Leader Key.

## Why Keywink

- **Sequences instead of chords.** `o` then `m` opens Messages. Nest groups as deep as you like; the guide follows you down and Backspace takes you up one level.
- **Key Guide.** A centered, single-column guide styled after editor completion lists: key badge first, then icon and name, with global shortcut hints on the right. Native materials, light and dark appearance, reduced motion and transparency respected.
- **Hyper group shortcuts.** Bind a global shortcut, such as Hyper+G, straight to a group and jump into it with one press. The guide shows **✦** for Hyper (Control–Option–Shift–Command).
- **Local usage statistics.** See which shortcuts you use from which app, and optionally rank the guide by frequency. Counts never leave your Mac.
- **Plain JSON configuration** with a built-in editor, validation, and automatic saving.
- **Automation** through `keywink://` URLs.

## Install

Download the latest `Keywink-<version>.zip` from [Releases](https://github.com/niklas-heer/Keywink/releases), unzip it, and move `Keywink.app` to Applications. Keywink runs as a menu bar item.

Releases are signed with a Developer ID certificate and notarized by Apple, so the app opens without extra steps. Verify downloads against the `.sha256` file attached to each release.

Keywink requires macOS 13 Ventura or later and runs natively on Apple Silicon and Intel. There is no Homebrew cask yet.

## Quick start

1. Click the Keywink menu bar item and choose **Settings…**.
2. Under **General**, record the shortcut that opens the launcher.
3. Add actions and groups in the configuration editor. Each item gets a single key.
4. Press your shortcut, then the keys. **Escape** dismisses the guide.

Actions can be applications, URLs, folders, or shell commands.

## Key Guide

<p align="center">
  <img alt="Key Guide inside a group, with the path in the header" src="docs/images/key-guide-group-dark.png" width="440">
</p>

The guide sits in the middle of the active display and keeps a steady width and center while its height follows the current group, up to ten rows before scrolling. The header shows the path to the current group on the left and the key sequence that reaches it on the right, where **›** means "then".

- **Backspace** or the back arrow moves up one level. At the root it does nothing.
- **Escape** hides the guide.
- Labels that start with an emoji use it as the icon.
- **Settings → General → Theme** switches to the other themes inherited from Leader Key. Existing "Top Edge" selections map to Key Guide.

## Groups and Hyper shortcuts

Give a top-level group a key, then use **Record Shortcut** beside it to assign a global shortcut. For example, bind Hyper+G to an applications group, release Hyper, and press `T` for Terminal. Group shortcuts always open their group from the root, even when another group is open.

If Raycast or another utility supplies Hyper, keep it running and match its **Include Shift** setting. Avoid binding a combination another launcher already owns. Global shortcuts are stored in Keywink's preferences, not in the JSON configuration.

## Usage statistics

**Settings → Statistics** shows launcher opens, group views, and action selections grouped by the app you were in when Keywink opened. Window titles, document contents, commands, and URLs are never recorded.

- **Track usage** pauses counting when turned off. **Reset statistics** clears history.
- **Rank via frequency** is off by default. When on, Key Guide orders siblings by how often you use them from the current app, falling back to overall counts. Ties keep configured order, keys never change, and the JSON file is never reordered.

Counts follow key paths, so reassigning a key inherits that path's history until reset.

## Import from Leader Key

Choose **Settings → General → Import Leader Key config…** and select the existing `config.json`, normally under `~/Library/Application Support/Leader Key/`. Keywink validates the file, backs up its current configuration, and copies the selection into its own directory. The original is left untouched.

Only the JSON configuration is imported. Record your activation shortcut and preferences in Keywink, and update any `leaderkey://` automation URLs to `keywink://`. Do not give both apps the same global shortcut.

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

## Development

Install Xcode with the macOS SDK, complete its first-launch setup, and install [mise](https://mise.jdx.dev/). Xcode provides Swift and the formatter; Swift Package Manager dependencies are locked in the project. No Homebrew packages are required.

```sh
mise trust
mise run build     # unsigned Debug build
mise run test      # isolated test suite
mise run check     # strict lint, script syntax, and tests (what CI runs)
mise run format    # rewrite Swift sources in place
```

Tests use temporary configuration directories and a process-private preferences domain, so they never touch your real configuration. See [AGENTS.md](AGENTS.md) for the architecture and coding guidelines, and [RELEASE.md](RELEASE.md) for signing, notarization, and packaging.

## Releases and updates

Builds are published on [GitHub Releases](https://github.com/niklas-heer/Keywink/releases). Keywink does not check for updates yet: Sparkle stays disabled until Keywink has its own HTTPS appcast and signing key. Until then, download new versions from the releases page.

## Contributing

Issues and pull requests are welcome in [Keywink's issue tracker](https://github.com/niklas-heer/Keywink/issues). The [decision records](decisions/) explain the fork baseline and the choices made since; new significant choices get a record too. Upstream fixes are reviewed against a focused command-launcher scope.

## License

MIT. See [LICENSE](LICENSE).

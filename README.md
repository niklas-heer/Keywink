# Keywink

A native macOS command launcher with memorable key sequences, visual hints, and a focus on easy configuration.

Keywink is an independent fork of [Leader Key](https://github.com/mikker/LeaderKey), created by Mikkel Malmberg and its contributors. Their history and [MIT license](LICENSE) are preserved.

## Fork status

This is the initial source fork. There is no Keywink release yet. The Xcode project, app identity, configuration location, URL scheme, signing settings, and update infrastructure still use the inherited Leader Key setup. The download and Homebrew instructions in the upstream documentation below install **Leader Key**, not Keywink.

Proposed first milestone:

1. Isolate configuration tests from real user files and establish a reproducible build/test baseline.
2. Give Keywink its own app identity and release/update configuration, with an explicit import path for existing Leader Key settings.
3. Review upstream fixes and editor/overlay improvements against a focused command-launcher scope.

See [development guidance](AGENTS.md) for inherited commands and the known test-isolation issue, and [decisions](DECISIONS.md) for the fork baseline. Track Keywink work in [this repository's issues](https://github.com/niklas-heer/Keywink/issues).

## Upstream documentation

The following is inherited Leader Key documentation, including the original author's announcement and installation links.

### Upstream announcement: Leader Key has been surpassed by [Tuna](https://tunaformac.com)

Tuna is a complete launcher – much more capable, and with **Leader Key built in!**

[![Meet Tuna](https://img.youtube.com/vi/vkm-ZFlivyI/mqdefault.jpg)](https://www.youtube.com/watch?v=vkm-ZFlivyI)

[Leader Key will stay free and open source](https://github.com/mikker/LeaderKey/discussions/314#discussioncomment-15939059) but my focus will be on Tuna going forward. 

---
  
<img src="https://s3.brnbw.com/icon_1024-akc2Ij3q9JOyhQ6Y7Lz6AFkX6nQQFhrQaRPqbV4vor0A62EA0vq4xOGrXpg6PVKi3aUJxOAyItkyktblPtZD4K4oYZ1bJVdh96VE.png" width="256" height="256" alt="Leader Key.app" />

**The \*faster than your launcher\* launcher**

A riff on [Raycast](https://www.raycast.com), [@mxstbr's multi-key Karabiner setup](https://www.youtube.com/watch?v=m5MDv9qwhU8&t=540s), and Vim's `<leader>` key.

Watch the intro video on YouTube:

<div>
<a href="https://www.youtube.com/watch?v=EQYakLsYSAQ"><img src="https://img.youtube.com/vi/EQYakLsYSAQ/maxresdefault.jpg" width=480></a>
<a href="https://www.youtube.com/watch?v=hzzQl5FOL-k"><img src="https://img.youtube.com/vi/hzzQl5FOL-k/maxresdefault.jpg" width=480></a>
</div>

*Yes, I only have that one thumbnail face.*

## Install

**Download**

📦 [Download latest version](https://github.com/mikker/LeaderKey.app/releases)
or

**Homebrew**

```sh
$ brew install leader-key
```

### Post-Install setup
- Open the settings menu with the menu bar icon <img width="17" alt="Screenshot 2025-05-21 at 1 58 46 PM" src="https://github.com/user-attachments/assets/7ba2cd99-dbd1-4b23-a35b-c5579e797321" />
- Choose your [`leader`](#what-do-i-set-as-my-leader-key) (`Shortcut` that will open the app) 

  <img width="213" alt="Screenshot 2025-05-21 at 2 01 56 PM" src="https://github.com/user-attachments/assets/5e486a9a-ee1c-4ac7-a2d9-f4d0a46eb734" />
- Add your [shortcuts](#example-shortcuts) to the `Config` settings

## Why Leader Key?

### Problems with traditional launchers:

1. Typing the name of the thing can be slow and give unpredictable results.
2. Global shortcuts have limited combinations.
3. Leader Key offers predictable, nested shortcuts -- like combos in a fighting game.

### Example Shortcuts:

- <kbd>leader</kbd><kbd>o</kbd><kbd>m</kbd> → Launch Messages (`open messages`)
- <kbd>leader</kbd><kbd>m</kbd><kbd>m</kbd> → Mute audio (`media mute`)
- <kbd>leader</kbd><kbd>w</kbd><kbd>m</kbd> → Maximize current window (`window maximize`)

## URL Scheme

Leader Key supports URL scheme automation for integration with tools like Alfred, Raycast, shell scripts, and more.

### Available URL Schemes

#### Configuration Management
```bash
# Reload configuration from disk
open "leaderkey://config-reload"

# Show config.json in Finder
open "leaderkey://config-reveal"
```

#### Window Control
```bash
# Show Leader Key window
open "leaderkey://activate"

# Hide Leader Key window
open "leaderkey://hide"

# Clear navigation state (return to root)
open "leaderkey://reset"
```

#### Settings & Info
```bash
# Open settings window
open "leaderkey://settings"

# Show about dialog
open "leaderkey://about"
```

#### Navigation
```bash
# Navigate through keys and execute actions
open "leaderkey://navigate?keys=a,b,c"

# Navigate without executing (preview mode)
open "leaderkey://navigate?keys=a,b,c&execute=false"
```

### Example Use Cases

- **Alfred/Raycast workflows**: Trigger Leader Key shortcuts programmatically
- **Shell scripts**: Automate configuration reloads after editing config.json
- **Keyboard maestro**: Chain Leader Key actions with other automations
- **External triggers**: Open specific action sequences from other applications

## FAQ

#### What do I set as my Leader Key?

Any key can be your leader key, but **only modifiers will not work**.

**Examples:**

- <kbd>F12</kbd>
- <kbd>⌘ + space</kbd>
- <kbd>⌘⌥ + space</kbd>
- <kbd>⌘⌥⌃⇧ + L</kbd> (hyper key)

**Advanced examples:**

Using [Karabiner](https://karabiner-elements.pqrs.org/) you can do more fancy things like:

- <kbd>right ⌘ + left ⌘</kbd> at once (bound to <kbd>F12</kbd>) my personal favorite
- <kbd>caps lock</kbd> (bound to <kbd>hyper</kbd> when held, <kbd>F12</kbd> when pressed)

See [@mikker's config](https://github.com/mikker/LeaderKey.app/wiki/@mikker's-config) in the wiki for akimbo cmds example.

#### I disabled the menubar item, how can I get Leader Key back?

Activate Leader Key, then <kbd>cmd + ,</kbd>.

#### Command action is failing with "Command not found"

You need to make sure your shell environment is correctly set up for non-interactive mode, and exports the `PATH` variable.

**For zsh** make sure you have your `PATH` variable exported in `~/.zshenv`

**For bash** make sure you have your `PATH` variable exported in `~/.bash_profile`


## License

MIT

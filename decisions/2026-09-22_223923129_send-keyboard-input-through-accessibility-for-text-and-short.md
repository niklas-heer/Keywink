+++
schema_version = 1
id = "01M35MC5FSWEVF2BKQX267XXSK"
title = "Send keyboard input through Accessibility for text and shortcut actions"
date = "2026-09-22"
status = "accepted"
tags = ["actions", "permissions"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: implemented and verified.

## Decision

Keywink offers two action types that send keyboard input to the frontmost application: `text` types its value as Unicode input, and `shortcut` presses one key combination written as `cmd+shift+4`, `⌘⇧4`, or `ctrl-alt-delete`. Both post CoreGraphics keyboard events from `KeySimulator` and therefore require the Accessibility permission. The controller asks macOS to prompt on the first attempt and otherwise shows an alert that names the setting; nothing else in the app depends on the permission. Text and shortcut actions always close the guide first, even in sticky mode, so the input reaches the app the user came from.

## Context

Upstream Leader Key requests text snippet insertion (#322) and simulated key presses (#316). Typing through the pasteboard would clobber the user's clipboard and needs a restore timer; Unicode key events avoid that and work for any keyboard layout, at the cost of the permission. AppleScript `System Events` would need the Automation permission instead and is slower. Sending input while the nonactivating panel is key would deliver it to Keywink itself, which is why these actions never run in sticky mode.

Shortcut parsing reuses the configuration's key names from `KeyMaps` (so `delete` means forward delete and `backspace` the Delete key) and adds punctuation, function, and navigation keys. The validator reports an unparseable shortcut or empty text as an `invalidValue` error on the row.

## Consequences

Users who never add these actions are never asked for Accessibility. Hardened Runtime and notarization are unaffected. Key codes assume the ANSI layout for punctuation; letters and digits go through the same table the guide already uses. A future "type slowly" or per-app delay can be added inside `KeySimulator` without touching the actions.

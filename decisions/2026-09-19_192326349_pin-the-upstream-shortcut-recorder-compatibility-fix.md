+++
schema_version = 1
id = "01M2XHZ78DVSXTY5Z2SJHR9GV2"
title = "Pin the upstream shortcut-recorder compatibility fix"
date = "2026-09-19"
status = "accepted"
tags = ["shell"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: implemented under the requested Hyper shortcut fix.

On the local macOS 27 build, both main and group recorders gained focus but immediately returned to **Record Shortcut**. Hyper+W/B saved nothing, and an ordinary letter appeared as editable text. This matches upstream [KeyboardShortcuts issue 241](https://github.com/sindresorhus/KeyboardShortcuts/issues/241), rather than a restriction on Hyper modifiers.

Pin KeyboardShortcuts to immutable revision [`b90d44a5809b4657cdf8bf3ee4d73a0a24c7d79f`](https://github.com/sindresorhus/KeyboardShortcuts/commit/b90d44a5809b4657cdf8bf3ee4d73a0a24c7d79f). It includes the [macOS 26/27 recorder fix](https://github.com/sindresorhus/KeyboardShortcuts/commit/df7b7ce53a2cfa4434513411f24972dd5ae0b50d): retain the event-monitor token, tolerate AppKit field-editor restarts, keep pause-state ownership with the active recorder, and let clear-button mouse events through. The pinned follow-up also unregisters hotkeys while recording so an existing shortcut can be recorded again. Tagged 3.0.1 lacks these fixes. Use the upstream implementation instead of maintaining a local copy or runtime patch; keep shortcut registration on the main actor to meet its concurrency contract.

The exact dependency revision is an implementation choice within the user-authorized fix. Revisit the pin when an upstream tagged release includes both fixes, retaining the native recording regression coverage. Hyper mapping remains the responsibility of the user's keyboard utility; recording a shortcut does not reconfigure Raycast or migrate existing Hammerspoon bindings.

Verification: Debug and unsigned universal Release builds pass, as do all 52 tests and required formatting/script checks. The new native recorder regression uses in-memory shortcut storage and checks focus survival, recording Hyper+W, replacing it with Hyper+B, and Escape cancellation without touching user preferences. The rebuilt settings UI also saved both combinations on a real group. Niklas then confirmed that physical Caps Lock+W through Raycast opens the assigned group while another app is active. The temporary test binding was cleared afterward; existing Hammerspoon bindings were preserved.

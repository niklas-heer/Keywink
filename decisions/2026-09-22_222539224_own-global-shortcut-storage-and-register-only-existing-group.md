+++
schema_version = 1
id = "01M35KK0WRS73X9VZJRNSMEZ8E"
title = "Own global shortcut storage and register only existing groups"
date = "2026-09-22"
status = "accepted"
tags = ["testing", "shortcuts"]
supersedes = []
superseded_by = []
depends_on = []
related_to = ["01M2XHZ779XSM9CQCB87GYA6P7"]
+++
Status: implemented and verified.

## Decision

Keywink reads and writes every persisted global shortcut through `GlobalShortcuts` instead of calling the KeyboardShortcuts name-based storage directly. Recorders use the library's binding-based initializers and hand the value to `GlobalShortcuts`. In the app the type forwards to KeyboardShortcuts, which stores the shortcut in `UserDefaults.standard` and registers the hotkey. In the test host it keeps shortcuts in a process-private dictionary, and `AppDelegate.registerGlobalShortcuts()` returns early.

Group shortcuts are registered only for keys that still name a first-level group in the loaded configuration. Deleting or renaming a first-level group in the editor removes its stored shortcut; the app re-evaluates the registered set whenever the configuration root changes.

## Context

The existing test isolation (see the test-isolation decision) redirects `Defaults` keys and the configuration directory to process-private locations, but KeyboardShortcuts hard-codes `UserDefaults.standard` and does not accept a suite. Because the hosted test bundle runs inside the real Keywink binary, recorders in tests showed the user's real activation shortcut, and any test that recorded, reset, or renamed a group could have changed or deleted the real preferences. The library's binding mode runs the same validation as name mode (menu, system, and disallowed shortcuts), so nothing is lost by owning the storage call.

Upstream Leader Key issue #289 reports that a deleted group keeps its global hotkey until the preferences file is edited by hand, and #290 reports a hotkey that "fires for no reason". Keywink inherited that behaviour: `registerGlobalShortcuts()` registered every key in `Defaults[.groupShortcuts]` even when no such group existed.

Alternatives considered: swapping the whole preferences domain for the test host (a crash would lose the user's preferences), a test-only branch in each recorder view (duplicated code paths), and forking KeyboardShortcuts to accept a suite (maintenance cost for one call site).

## Consequences

Tests can set, read, and clear shortcuts freely and can assert that `UserDefaults.standard` stays untouched. Stored shortcuts of groups that vanish through an external configuration edit stay in the preferences but are not registered, so re-adding the group restores the hotkey. A future upstream change that lets KeyboardShortcuts use a custom suite would make the in-memory backend unnecessary but not the facade.

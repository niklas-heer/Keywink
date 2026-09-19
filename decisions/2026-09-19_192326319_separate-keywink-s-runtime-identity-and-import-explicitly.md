+++
schema_version = 1
id = "01M2XHZ77F45K2B89121322H2Z"
title = "Separate Keywink's runtime identity and import explicitly"
date = "2026-09-19"
status = "accepted"
tags = ["runtime"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: implemented under the authorized identity-migration milestone.

Ship `Keywink.app` with bundle identifier `de.niklas-heer.Keywink`, configuration under `~/Library/Application Support/Keywink`, and the `keywink://` URL scheme. Start Keywink's version sequence at `0.1.0` build `1`. Replace visible branding and icons; keep the inherited internal Xcode project, targets, scheme, source paths, and `Leader_Key` module to avoid unrelated source-path churn. Preserve upstream Git history, attribution, and license.

Do not automatically share or move Leader Key's preferences or files. An explicit settings import accepts an existing JSON configuration, validates it, backs up the destination, and copies the data without changing its source. Pending saves/loads must not overwrite the imported state. Activation shortcuts, preferences, and login registration are configured separately. Leader Key's URL scheme is not registered or handled.

Verification: all 47 tests pass, including import persistence/failure cases, pending-I/O handling, built bundle identity, URL parsing, and updater configuration. Debug and universal Intel/Apple Silicon Release builds pass. Real configuration fingerprints remain unchanged after tests.

This completes the runtime-identity portion left pending in Decision 1. The bundle identifier and migration mechanics are implementation choices within the requested milestone; they were not separately specified by the user.

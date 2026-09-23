+++
schema_version = 1
id = "01M36QMRXYDAB41W9G77VQ9H2C"
title = "Serve Sparkle updates from the newest GitHub release's appcast"
date = "2026-09-23"
status = "accepted"
tags = ["release", "updates"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
* **Status**: ✅ Accepted
* **Decision**: I will serve Sparkle updates for Keywink from GitHub Releases: each release attaches a signed `appcast.xml` listing only that release, and the app's feed URL is `https://github.com/niklas-heer/Keywink/releases/latest/download/appcast.xml`.
* **Context**: Niklas asked on 2026-09-23 for an auto-update mechanism based on GitHub releases for Keywink and Spokn. Sparkle was already wired but disabled for lack of a feed. Alternatives were a GitHub Pages appcast (a second publishing step and a branch to maintain) or the inherited Leader Key S3 workflow (removed on purpose). GitHub's `latest/download/<asset>` URL redirects to the newest release's asset, so the feed needs no extra hosting. A single-item appcast suffices because every installed version should move straight to the newest release; delta updates and version history are not needed.
* **Consequences**: `bin/archive` defaults the feed URL and the published Ed25519 public key, so release builds enable the updater unless both are set empty. `bin/release` generates and verifies the appcast with Sparkle's SwiftPM tools. Every release must attach `appcast.xml`, or installed apps stop seeing updates. One Sparkle key in the release machine's login Keychain (account `ed25519`) signs updates for both apps; it must be backed up in a password manager. Ad-hoc and unconfigured builds keep the updater disabled. The first release with updates enabled is 0.2.1; 0.2.0 and older installs update manually once.

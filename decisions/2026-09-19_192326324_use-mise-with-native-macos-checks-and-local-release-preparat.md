+++
schema_version = 1
id = "01M2XHZ77MSG10K5NFZ24MGHFA"
title = "Use mise with native macOS checks and local release preparation"
date = "2026-09-19"
status = "accepted"
tags = ["release", "tooling"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: implemented; public release and update service not activated.

The user explicitly selected mise for setup. Use it for native Xcode build/test tasks, explicit formatting, strict lint, and release preparation. Xcode supplies Swift and swift-format; the existing SwiftPM lockfile fixes app dependencies. CI pins Xcode 26.6 on macOS. AppKit and Xcode require native macOS coverage, so the usual Dagger preference would not replace this check. Fix the two inherited whitespace warnings with Xcode's formatter so CI can enforce strict, non-mutating lint.

Use Keywink's GitHub releases for future artifacts. The local release scripts create a fresh Developer ID archive, export, notarize, staple, verify, and package the app with a checksum. They do not tag, publish, upload to an upstream bucket, or auto-commit. Supply the Apple team/certificate and notary Keychain profile outside the repository. These external signing steps require maintainer setup before the first public release.

Remove the inherited Apple team, S3 uploader, appcast workflow, Sparkle key/feed, and checked-in Sparkle executables. Instantiate Sparkle only when a valid HTTPS feed and 32-byte public key are explicitly supplied through Keywink build settings. Until then, the app links to Keywink's release page. An independently hosted appcast, retained private key, and real signed-update test remain prerequisites before enabling updates. See [RELEASE.md](../RELEASE.md) and [Sparkle's programmatic setup](https://sparkle-project.org/documentation/programmatic-setup/).

+++
schema_version = 1
id = "01M2XHZ779XSM9CQCB87GYA6P7"
title = "Isolate tests before establishing the build baseline"
date = "2026-09-19"
status = "accepted"
tags = ["testing"]
supersedes = []
superseded_by = []
depends_on = []
related_to = []
+++
Status: implemented and verified.

The inherited configuration tests deleted the real default configuration directory. Changing a global UserDefaults variable per fixture also failed to redirect already-initialized Defaults keys. The app and defaults code used different XCTest detection markers, and a storyboard-created Sparkle controller started before the app's test guard.

Use one test-runtime detector for both XCTest environment markers and the XCTest runtime class. Tests receive an immutable process-private preferences suite and temporary default configuration path; configuration fixtures additionally inject their own directory accessors and fallback resolver. Start the updater programmatically after the test guard. Never perform configuration test cleanup against Application Support.

The baseline Debug build and all 36 tests passed on Xcode 26.6. Before/after file fingerprints confirmed the real Leader Key and Keywink configuration directories were unchanged. The local Xcode installation first required `xcodebuild -runFirstLaunch` to repair a missing DVTDownloads symbol; this was a machine setup issue, not an app defect.

Remove the inherited source-mutating formatting build phase and its approval-requiring formatting plug-in. Formatting is an explicit mise task, so compiling no longer rewrites source or requires trusting an unrelated build plug-in. This supersedes the initial unsafe-test warning; upstream PR 313 was not adopted as a presumed fix.

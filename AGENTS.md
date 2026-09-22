# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

# Keywink Development Guide

Keywink is an independent fork of Leader Key. Read [README.md](README.md) for fork status and [decision records](decisions/) for the accepted identity and upstream baseline. The Xcode project, scheme, targets, source directories, and Swift module are all named Keywink. See [RELEASE.md](RELEASE.md) for the local release process and external signing prerequisites.

## Build & Test Commands

- Build: `mise run build`
- Run all tests: `mise run test`
- Run required checks: `mise run check` (strict formatting, native tests, and script syntax)
- Run single test: `xcodebuild -scheme "Keywink" -testPlan "TestPlan" '-only-testing:KeywinkTests/UserConfigTests/testInitializesWithDefaults' -derivedDataPath build CODE_SIGNING_ALLOWED=NO test`
- Format source explicitly: `mise run format` (builds never rewrite source)
- Render the Settings panes for review: `mise run snapshots` (writes `build/snapshots/pane-*.png`; AppKit-backed controls render as placeholders)
- Set release version: `bin/bump <marketing-version> <build-number>`
- Prepare signed, notarized artifacts: `mise run release` (requires the configuration in RELEASE.md; does not publish)

Use the Xcode-provided Swift toolchain. CI stays on macOS because AppKit and Xcode cannot be tested in a Linux Dagger container.

## Architecture Overview

Keywink is a macOS application that provides customizable keyboard shortcuts. The core architecture consists of:

**Key Components:**

- `AppDelegate`: Application lifecycle, global shortcuts registration, update management
- `Controller`: Central event handling, manages key sequences and window display
- `UserConfig`: JSON configuration management with validation
- `UserState`: Tracks navigation through key sequences
- `MainWindow`: Base class for theme windows

**Theme System:**

- Themes inherit from `MainWindow`, host SwiftUI content, and implement show/hide behavior
- Available themes: Key Guide (default; internal `TopEdge`/`topEdge` names retained for preference compatibility), MysteryBox, Mini, Breadcrumbs, ForTheHorde, Cheater
- Key Guide includes its own single-column shortcut list, icons, and group path. Center it in the selected screen's visible frame using global coordinates; bound its size to the usable area.
- Backspace pops one navigation level. Usage statistics aggregate local key-path counts by source application; tests must inject isolated preferences. Frequency ranking changes presentation order only.
- Each theme provides different visual representations of shortcuts

**Configuration Flow:**

- Config stored at `~/Library/Application Support/Keywink/config.json`
- Configuration changes save automatically; explicit reload and the settings import flow update the in-memory configuration
- `ConfigValidator` ensures no key conflicts
- Actions support: applications, URLs, commands, folders
- Leader Key JSON import is explicit, validates before replacing, and preserves both the source and a backup of the Keywink configuration. Do not silently share upstream preferences or configuration.
- Sparkle starts only with a configured HTTPS feed and valid public key; never restore upstream update infrastructure.

**Testing Architecture:**

- Uses XCTest with custom `TestAlertManager` for UI testing
- Tests use a process-private UserDefaults suite and temporary default configuration directory. Configuration fixtures inject their own directory accessors and fallback path; never delete or write the real user configuration directory in tests. App and updater startup are suppressed in the test host. Global shortcuts go through `GlobalShortcuts`, which keeps them in memory in the test host because KeyboardShortcuts can only use `UserDefaults.standard`; never call its name-based storage directly. Keep this isolation when adding tests.
- Focus on configuration validation and state management

## Code Style Guidelines

- **Imports**: Group Foundation/AppKit imports first, then third-party libraries (Combine, Defaults)
- **Naming**: Use descriptive camelCase for variables/functions, PascalCase for types
- **Types**: Use explicit type annotations for public properties and parameters
- **Error Handling**: Use appropriate error handling with do/catch blocks and alerts
- **Extensions**: Create extensions for additional functionality on existing types
- **State Management**: Use @Published and ObservableObject for reactive UI updates
- **Testing**: Create separate test cases with descriptive names, use XCTAssert\* methods
- **Access Control**: Use appropriate access modifiers (private, fileprivate, internal)
- **Documentation**: Use comments for complex logic or non-obvious implementations

Follow Swift idioms and default formatting (4-space indentation, spaces around operators).

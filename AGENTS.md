# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

# Keywink Development Guide

Keywink is an independent fork of Leader Key. Read [README.md](README.md) for fork status and [DECISIONS.md](DECISIONS.md) for the accepted identity and upstream baseline. The Xcode scheme and source paths still use Leader Key names. Release and app-identity migration are pending; the inherited release commands below are references, not a configured Keywink release process.

## Build & Test Commands

- Build and run: `xcodebuild -scheme "Leader Key" -configuration Debug build`
- Run all tests: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" test`
- Run single test: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" '-only-testing:Leader KeyTests/UserConfigTests/testInitializesWithDefaults' test`
- Bump version: `bin/bump`
- Create release: `bin/release`

## Architecture Overview

Leader Key is a macOS application that provides customizable keyboard shortcuts. The core architecture consists of:

**Key Components:**

- `AppDelegate`: Application lifecycle, global shortcuts registration, update management
- `Controller`: Central event handling, manages key sequences and window display
- `UserConfig`: JSON configuration management with validation
- `UserState`: Tracks navigation through key sequences
- `MainWindow`: Base class for theme windows

**Theme System:**

- Themes inherit from `MainWindow` and implement `draw()` method
- Available themes: MysteryBox, Mini, Breadcrumbs, ForTheHorde, Cheater
- Each theme provides different visual representations of shortcuts

**Configuration Flow:**

- Config stored at `~/Library/Application Support/Leader Key/config.json`
- `FileMonitor` watches for changes and triggers reload
- `ConfigValidator` ensures no key conflicts
- Actions support: applications, URLs, commands, folders

**Testing Architecture:**

- Uses XCTest with custom `TestAlertManager` for UI testing
- Tests use a process-private UserDefaults suite and temporary default configuration directory. Configuration fixtures inject their own directory accessors and fallback path; never delete or write the real user configuration directory in tests. App and updater startup are suppressed in the test host. Keep this isolation when adding tests.
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

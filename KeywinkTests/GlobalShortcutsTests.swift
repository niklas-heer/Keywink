import KeyboardShortcuts
import XCTest

@testable import Keywink

final class GlobalShortcutsTests: XCTestCase {
  private let shortcut = KeyboardShortcuts.Shortcut(.k, modifiers: [.command, .option])

  @MainActor
  func testStoresShortcutsWithoutTouchingTheRealPreferences() {
    let key = "test-\(UUID().uuidString)"
    let name = GlobalShortcuts.groupName(for: key)
    let defaultsKey = "KeyboardShortcuts_\(name.rawValue)"
    defer { GlobalShortcuts.remove(name) }

    XCTAssertNil(GlobalShortcuts.shortcut(for: name))

    GlobalShortcuts.set(shortcut, for: name)
    XCTAssertEqual(GlobalShortcuts.shortcut(for: name), shortcut)
    XCTAssertNil(
      UserDefaults.standard.object(forKey: defaultsKey),
      "the test host must keep shortcuts in memory, not in the app's preferences")
    XCTAssertNil(KeyboardShortcuts.getShortcut(for: name))

    GlobalShortcuts.remove(name)
    XCTAssertNil(GlobalShortcuts.shortcut(for: name))
  }

  func testActiveGroupKeysDropShortcutsOfMissingGroups() {
    let root = Group(
      key: nil,
      actions: [
        .group(Group(key: "o", actions: [])),
        .group(Group(key: "m", actions: [])),
        .group(Group(key: "", actions: [])),
        .action(Action(key: "w", type: .url, value: "https://example.com")),
      ])

    let active = GlobalShortcuts.activeGroupKeys(in: root, stored: ["o", "w", "x", ""])

    XCTAssertEqual(active, ["o"])
  }

  func testActiveGroupKeysIgnoreNestedGroups() {
    let nested = Group(key: "n", actions: [])
    let root = Group(
      key: nil,
      actions: [.group(Group(key: "o", actions: [.group(nested)]))])

    XCTAssertEqual(GlobalShortcuts.activeGroupKeys(in: root, stored: ["o", "n"]), ["o"])
  }
}

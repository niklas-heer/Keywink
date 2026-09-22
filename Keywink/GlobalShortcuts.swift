import Foundation
import KeyboardShortcuts

/// Keywink's single entry point for persisted global shortcuts.
///
/// KeyboardShortcuts can only store shortcuts in `UserDefaults.standard`, which the hosted
/// test bundle shares with the real app. Routing every read and write through this type lets
/// the test host keep shortcuts in memory, so tests never display, overwrite, or delete the
/// user's shortcuts. Outside tests every call goes straight to KeyboardShortcuts, which also
/// registers and unregisters the matching hotkey.
@MainActor
enum GlobalShortcuts {
  /// Name under which the global shortcut of a first-level group is stored.
  nonisolated static func groupName(for key: String) -> KeyboardShortcuts.Name {
    KeyboardShortcuts.Name("group-\(key)")
  }

  static func shortcut(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.Shortcut? {
    if RuntimeEnvironment.isRunningTests {
      return memory[name.rawValue]
    }
    return KeyboardShortcuts.getShortcut(for: name)
  }

  /// Stores `shortcut`, or removes the stored shortcut when `nil`.
  static func set(_ shortcut: KeyboardShortcuts.Shortcut?, for name: KeyboardShortcuts.Name) {
    if RuntimeEnvironment.isRunningTests {
      memory[name.rawValue] = shortcut
      return
    }
    KeyboardShortcuts.setShortcut(shortcut, for: name)
  }

  static func remove(_ name: KeyboardShortcuts.Name) {
    set(nil, for: name)
  }

  /// Keys of first-level groups in `root` that have a stored global shortcut. Keys that no
  /// longer name a group are ignored so a deleted or renamed group never keeps its hotkey.
  nonisolated static func activeGroupKeys(in root: Group, stored: Set<String>) -> Set<String> {
    let groupKeys = root.actions.compactMap { item -> String? in
      guard case .group(let group) = item, let key = group.key, !key.isEmpty else { return nil }
      return key
    }
    return stored.intersection(groupKeys)
  }

  /// Backing store for the test host. Never used outside tests.
  private static var memory: [String: KeyboardShortcuts.Shortcut] = [:]
}

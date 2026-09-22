import Cocoa
import Defaults

enum RuntimeEnvironment {
  static var isRunningTests: Bool {
    isRunningTests(
      environment: ProcessInfo.processInfo.environment,
      hasXCTestCaseClass: NSClassFromString("XCTestCase") != nil)
  }

  static func isRunningTests(
    environment: [String: String], hasXCTestCaseClass: Bool
  ) -> Bool {
    environment["XCTestConfigurationFilePath"] != nil
      || environment["XCTestSessionIdentifier"] != nil
      || hasXCTestCaseClass
  }

  static let testConfigDirectory: String? = {
    guard isRunningTests else { return nil }

    return FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "KeywinkTests-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)",
        isDirectory: true
      )
      .path
  }()
}

let defaultsSuite: UserDefaults = {
  guard RuntimeEnvironment.isRunningTests else { return .standard }

  return UserDefaults(
    suiteName:
      "de.niklas-heer.KeywinkTests-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString)"
  )!
}()

extension Defaults.Keys {
  static let configDir = Key<String>(
    "configDir", default: UserConfig.defaultDirectory(), suite: defaultsSuite)
  static let showMenuBarIcon = Key<Bool>(
    "showInMenubar", default: true, suite: defaultsSuite)
  static let forceEnglishKeyboardLayout = Key<Bool>(
    "forceEnglishKeyboardLayout", default: false, suite: defaultsSuite)
  static let modifierKeyConfiguration = Key<ModifierKeyConfig>(
    "modifierKeyConfiguration", default: .controlGroupOptionSticky, suite: defaultsSuite)
  static let theme = Key<Theme>(
    "theme", default: .topEdge, suite: defaultsSuite)
  static let trackUsage = Key<Bool>("trackUsage", default: true, suite: defaultsSuite)
  static let rankByFrequency = Key<Bool>("rankByFrequency", default: false, suite: defaultsSuite)

  static let autoOpenCheatsheet = Key<AutoOpenCheatsheetSetting>(
    "autoOpenCheatsheet",
    default: .delay, suite: defaultsSuite)
  static let cheatsheetDelayMS = Key<Int>(
    "cheatsheetDelayMS", default: 2000, suite: defaultsSuite)
  static let expandGroupsInCheatsheet = Key<Bool>(
    "expandGroupsInCheatsheet", default: false, suite: defaultsSuite)
  static let showAppIconsInCheatsheet = Key<Bool>(
    "showAppIconsInCheatsheet", default: true, suite: defaultsSuite)
  static let showDetailsInCheatsheet = Key<Bool>(
    "showDetailsInCheatsheet", default: true, suite: defaultsSuite)
  static let showFaviconsInCheatsheet = Key<Bool>(
    "showFaviconsInCheatsheet", default: true, suite: defaultsSuite)
  static let reactivateBehavior = Key<ReactivateBehavior>(
    "reactivateBehavior", default: .hide, suite: defaultsSuite)
  static let screen = Key<Screen>(
    "screen", default: .primary, suite: defaultsSuite)

  static let groupShortcuts = Key<Set<String>>(
    "groupShortcuts",
    default: Set(), suite: defaultsSuite)
}

enum AutoOpenCheatsheetSetting: String, Defaults.Serializable {
  case never
  case always
  case delay
}

enum ModifierKeyConfig: String, Codable, Defaults.Serializable, CaseIterable, Identifiable {
  case controlGroupOptionSticky
  case optionGroupControlSticky

  var id: Self { self }

  var description: String {
    switch self {
    case .controlGroupOptionSticky:
      return "⌃ Group sequences, ⌥ Sticky mode"
    case .optionGroupControlSticky:
      return "⌥ Group sequences, ⌃ Sticky mode"
    }
  }

  /// Glyph of the modifier that runs a whole group.
  var groupModifierGlyph: String {
    switch self {
    case .controlGroupOptionSticky: return "⌃"
    case .optionGroupControlSticky: return "⌥"
    }
  }

  /// Glyph of the modifier that keeps Keywink open after an action.
  var stickyModifierGlyph: String {
    switch self {
    case .controlGroupOptionSticky: return "⌥"
    case .optionGroupControlSticky: return "⌃"
    }
  }
}

enum ReactivateBehavior: String, Defaults.Serializable {
  case hide
  case reset
  case nothing
}

enum Screen: String, Defaults.Serializable {
  case primary
  case mouse
  case activeWindow
}

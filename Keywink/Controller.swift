import Cocoa
import Combine
import Defaults
import SwiftUI

enum KeyHelpers: UInt16 {
  case enter = 36
  case tab = 48
  case space = 49
  case backspace = 51
  case escape = 53
  case upArrow = 126
  case downArrow = 125
  case leftArrow = 123
  case rightArrow = 124
}

class Controller {
  var userState: UserState
  var userConfig: UserConfig
  let usage: UsageStatistics
  private let sourceApplication: () -> (id: String, name: String)

  var window: MainWindow!
  var cheatsheetWindow: NSWindow!
  private var cheatsheetTimer: Timer?
  private let actionRunner: ((Action) -> Void)?

  /// The most recent action the user ran, for the repeat shortcut and URL.
  private(set) var lastAction: Action?

  /// While a sticky-mode action is running, another app may take focus. Until this deadline
  /// passes the panel re-takes key status instead of hiding (upstream Leader Key issue #223).
  private var stickyGraceDeadline: Date?
  static let stickyGracePeriod: TimeInterval = 1.5

  private var cancellables = Set<AnyCancellable>()

  init(
    userState: UserState, userConfig: UserConfig,
    usage: UsageStatistics = .shared,
    sourceApplication: @escaping () -> (id: String, name: String) = {
      let app = NSWorkspace.shared.frontmostApplication
      return (app?.bundleIdentifier ?? "unknown", app?.localizedName ?? "Unknown application")
    },
    actionRunner: ((Action) -> Void)? = nil
  ) {
    self.userState = userState
    self.userConfig = userConfig
    self.usage = usage
    self.sourceApplication = sourceApplication
    self.actionRunner = actionRunner

    Task {
      for await value in Defaults.updates(.theme) {
        let windowClass = Theme.classFor(value)
        self.window = await windowClass.init(controller: self)
      }
    }

    Events.sink { event in
      switch event {
      case .didReload:
        // This should all be handled by the themes
        self.userState.isShowingRefreshState = true
        self.show()
        // Delay for 4 * 300ms to wait for animation to be noticeable
        delay(Int(Pulsate.singleDurationS * 1000) * 3) {
          self.hide()
          self.userState.isShowingRefreshState = false
        }
      default: break
      }
    }.store(in: &cancellables)

    self.cheatsheetWindow = Cheatsheet.createWindow(for: userState)
  }

  func show() {
    if !window.isVisible && !userState.isShowingRefreshState {
      let source = sourceApplication()
      userState.sourceAppID = source.id
      if Defaults[.trackUsage] {
        usage.recordOpening(appID: source.id, appName: source.name)
      }
    }
    Events.send(.willActivate)

    let screen = Defaults[.screen].getNSScreen() ?? NSScreen()
    window.show(on: screen) {
      Events.send(.didActivate)
    }

    if !window.hasCheatsheet || userState.isShowingRefreshState {
      return
    }

    switch Defaults[.autoOpenCheatsheet] {
    case .always:
      showCheatsheet()
    case .delay:
      scheduleCheatsheet()
    default: break
    }
  }

  func openRootGroup(for key: String) {
    guard userState.openRootGroup(for: key) else { return }
    show()
    recordCurrentGroupView()
  }

  func goBack() {
    guard !userState.navigationPath.isEmpty else { return }
    userState.goBack()
    recordCurrentGroupView()
    positionCheatsheetWindow()
  }

  private func recordCurrentGroupView() {
    guard Defaults[.trackUsage], !userState.keyPath.isEmpty,
      let appID = userState.sourceAppID
    else { return }
    usage.recordGroup(path: userState.keyPath, appID: appID)
  }

  /// Runs the last action again without showing the panel.
  func repeatLastAction() {
    guard let action = lastAction else {
      NSSound.beep()
      return
    }
    runAction(action)
  }

  /// Windows call this when they stop being key. During the sticky grace period the panel
  /// stays open and takes key status back, so a launched app does not end sticky mode.
  func windowDidResignKey() {
    guard shouldStayOpenAfterResigningKey(now: Date()) else {
      hide()
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self, self.window.isVisible else { return }
      self.window.makeKeyAndOrderFront(nil)
    }
  }

  func shouldStayOpenAfterResigningKey(now: Date) -> Bool {
    guard let deadline = stickyGraceDeadline else { return false }
    return now < deadline
  }

  func hide(afterClose: (() -> Void)? = nil) {
    stickyGraceDeadline = nil
    Events.send(.willDeactivate)

    window.hide {
      self.clear()
      afterClose?()
      Events.send(.didDeactivate)
    }

    cheatsheetWindow?.orderOut(nil)
    cheatsheetTimer?.invalidate()
  }

  func keyDown(with event: NSEvent) {
    // Reset the delay timer
    if Defaults[.autoOpenCheatsheet] == .delay {
      scheduleCheatsheet()
    }

    if event.modifierFlags.contains(.command) {
      switch event.charactersIgnoringModifiers {
      case ",":
        NSApp.sendAction(
          #selector(AppDelegate.settingsMenuItemActionHandler(_:)), to: nil,
          from: nil)
        hide()
        return
      case "w":
        hide()
        return
      case "q":
        NSApp.terminate(nil)
        return
      default:
        break
      }
    }

    switch event.keyCode {
    case KeyHelpers.backspace.rawValue:
      goBack()
      delay(1) {
        self.positionCheatsheetWindow()
      }
    case KeyHelpers.escape.rawValue:
      stickyGraceDeadline = nil
      window.resignKey()
    default:
      guard let char = charForEvent(event) else { return }
      handleKey(char, withModifiers: event.modifierFlags)
    }
  }

  func handleKey(
    _ key: String, withModifiers modifiers: NSEvent.ModifierFlags? = nil, execute: Bool = true
  ) {
    if key == "?" {
      showCheatsheet()
      return
    }

    let list =
      (userState.currentGroup != nil)
      ? userState.currentGroup : userConfig.root

    let hit = list?.actions.first { item in
      switch item {
      case .group(let group):
        // Normalize both keys for comparison
        let groupKey = KeyMaps.glyph(for: group.key ?? "") ?? group.key ?? ""
        let inputKey = KeyMaps.glyph(for: key) ?? key
        if groupKey == inputKey {
          return true
        }
      case .action(let action):
        // Normalize both keys for comparison
        let actionKey = KeyMaps.glyph(for: action.key ?? "") ?? action.key ?? ""
        let inputKey = KeyMaps.glyph(for: key) ?? key
        if actionKey == inputKey {
          return true
        }
      }
      return false
    }

    switch hit {
    case .action(let action):
      if execute {
        recordActionUse(action, parentPath: userState.keyPath)
        // Typed text and shortcuts must reach the app under the panel, so they always close it.
        if let mods = modifiers, isInStickyMode(mods), !action.type.sendsKeyboardInput {
          stickyGraceDeadline = Date().addingTimeInterval(Controller.stickyGracePeriod)
          runAction(action)
        } else {
          hide {
            self.runAction(action)
          }
        }
      }
    // If execute is false, just stay visible showing the matched action
    case .group(let group):
      if execute, let mods = modifiers, shouldRunGroupSequenceWithModifiers(mods) {
        let path = userState.keyPath + [group.key ?? ""]
        hide {
          self.runGroup(group, path: path)
        }
      } else {
        userState.display = group.key
        userState.navigateToGroup(group)
        recordCurrentGroupView()
      }
    case .none:
      window.notFound()
    }

    // Why do we need to wait here?
    delay(1) {
      self.positionCheatsheetWindow()
    }
  }

  private func shouldRunGroupSequence(_ event: NSEvent) -> Bool {
    return shouldRunGroupSequenceWithModifiers(event.modifierFlags)
  }

  private func shouldRunGroupSequenceWithModifiers(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
    let config = Defaults[.modifierKeyConfiguration]

    switch config {
    case .controlGroupOptionSticky:
      return modifierFlags.contains(.control)
    case .optionGroupControlSticky:
      return modifierFlags.contains(.option)
    }
  }

  private func isInStickyMode(_ modifierFlags: NSEvent.ModifierFlags) -> Bool {
    let config = Defaults[.modifierKeyConfiguration]

    switch config {
    case .controlGroupOptionSticky:
      return modifierFlags.contains(.option)
    case .optionGroupControlSticky:
      return modifierFlags.contains(.control)
    }
  }

  internal func charForEvent(_ event: NSEvent) -> String? {
    let forceEnglish = Defaults[.forceEnglishKeyboardLayout]

    // 1. If the user forces English, or if the key is non-printable,
    //    fall back to the hard-coded map.
    if forceEnglish {
      return englishGlyph(for: event)
    }

    // 2. For special keys like Enter, always use the mapped glyph
    if let entry = KeyMaps.entry(for: event.keyCode) {
      // For Enter, Space, Tab, arrows, etc. - use the glyph representation
      if event.keyCode == KeyHelpers.enter.rawValue || event.keyCode == KeyHelpers.space.rawValue
        || event.keyCode == KeyHelpers.tab.rawValue
        || event.keyCode == KeyHelpers.leftArrow.rawValue
        || event.keyCode == KeyHelpers.rightArrow.rawValue
        || event.keyCode == KeyHelpers.upArrow.rawValue
        || event.keyCode == KeyHelpers.downArrow.rawValue
      {
        return entry.glyph
      }
    }

    // 3. Use the system-translated character for regular keys.
    if let printable = event.charactersIgnoringModifiers,
      !printable.isEmpty,
      printable.unicodeScalars.first?.isASCII ?? false
    {
      return printable  // already contains correct case
    }

    // 4. For arrows, ␣, ⌫ … use map as last resort.
    return englishGlyph(for: event)
  }

  private func englishGlyph(for event: NSEvent) -> String? {
    guard let entry = KeyMaps.entry(for: event.keyCode) else {
      return event.charactersIgnoringModifiers
    }
    if entry.glyph.first?.isLetter == true && !entry.isReserved {
      return event.modifierFlags.contains(.shift)
        ? entry.glyph.uppercased()
        : entry.glyph
    }
    return entry.glyph
  }

  private func positionCheatsheetWindow() {
    guard let mainWindow = window, let cheatsheet = cheatsheetWindow else {
      return
    }

    cheatsheet.setFrameOrigin(
      mainWindow.cheatsheetOrigin(cheatsheetSize: cheatsheet.frame.size))
  }

  private func showCheatsheet() {
    if !window.hasCheatsheet {
      return
    }
    positionCheatsheetWindow()
    cheatsheetWindow?.orderFront(nil)
  }

  private func scheduleCheatsheet() {
    cheatsheetTimer?.invalidate()

    cheatsheetTimer = Timer.scheduledTimer(
      withTimeInterval: Double(Defaults[.cheatsheetDelayMS]) / 1000.0, repeats: false
    ) { [weak self] _ in
      self?.showCheatsheet()
    }
  }

  private func runGroup(_ group: Group, path: [String]) {
    for groupOrAction in group.actions {
      switch groupOrAction {
      case .group(let group):
        runGroup(group, path: path + [group.key ?? ""])
      case .action(let action):
        recordActionUse(action, parentPath: path)
        runAction(action)
      }
    }
  }

  private func recordActionUse(_ action: Action, parentPath: [String]) {
    guard Defaults[.trackUsage], let appID = userState.sourceAppID,
      let key = action.key
    else { return }
    usage.recordAction(path: parentPath + [key], appID: appID)
  }

  /// True when `frontmostBundleURL` is the application bundle at `actionValue`.
  static func isSameApplication(_ frontmostBundleURL: URL?, _ actionValue: String) -> Bool {
    guard let frontmostBundleURL else { return false }
    let action = URL(fileURLWithPath: (actionValue as NSString).expandingTildeInPath)
    return frontmostBundleURL.standardizedFileURL.resolvingSymlinksInPath().path
      == action.standardizedFileURL.resolvingSymlinksInPath().path
  }

  private func runAction(_ action: Action) {
    lastAction = action
    if let actionRunner {
      actionRunner(action)
      return
    }

    switch action.type {
    case .application:
      if Defaults[.hideFrontmostApplication],
        let frontmost = NSWorkspace.shared.frontmostApplication,
        Controller.isSameApplication(frontmost.bundleURL, action.value)
      {
        frontmost.hide()
        break
      }
      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: action.value),
        configuration: NSWorkspace.OpenConfiguration())
    case .url:
      openURL(action)
    case .command:
      CommandRunner.run(action.value)
    case .folder:
      let path: String = (action.value as NSString).expandingTildeInPath
      NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    case .text:
      guard ensureAccessibilityPermission() else { break }
      KeySimulator.type(action.value)
    case .shortcut:
      guard ensureAccessibilityPermission() else { break }
      do {
        KeySimulator.press(try KeySimulator.parse(action.value))
      } catch let error as KeySimulator.ParseError {
        showAlert(title: "Invalid shortcut", message: "\(error.message): \(action.value)")
      } catch {
        showAlert(title: "Invalid shortcut", message: action.value)
      }
    default:
      print("\(action.type) unknown")
    }

    if window.isVisible {
      window.makeKeyAndOrderFront(nil)
    }
  }

  private func clear() {
    userState.clear()
  }

  /// Text and shortcut actions need Accessibility permission. The system prompt appears on
  /// the first attempt; afterwards an alert points to the setting.
  private func ensureAccessibilityPermission() -> Bool {
    if KeySimulator.isTrusted(prompt: true) { return true }
    showAlert(
      title: "Accessibility permission needed",
      message:
        "Allow Keywink under System Settings › Privacy & Security › Accessibility to type text and press shortcuts in other apps, then run the action again."
    )
    return false
  }

  private func openURL(_ action: Action) {
    guard let url = URL(string: action.value) else {
      showAlert(
        title: "Invalid URL", message: "Failed to parse URL: \(action.value)")
      return
    }

    guard let scheme = url.scheme else {
      showAlert(
        title: "Invalid URL",
        message:
          "URL is missing protocol (e.g. https://, raycast://): \(action.value)"
      )
      return
    }

    if scheme == "http" || scheme == "https" {
      NSWorkspace.shared.open(
        url,
        configuration: NSWorkspace.OpenConfiguration())
    } else {
      NSWorkspace.shared.open(
        url,
        configuration: DontActivateConfiguration.shared.configuration)
    }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}

class DontActivateConfiguration {
  let configuration = NSWorkspace.OpenConfiguration()

  static var shared = DontActivateConfiguration()

  init() {
    configuration.activates = false
  }
}

extension Screen {
  func getNSScreen() -> NSScreen? {
    switch self {
    case .primary:
      return NSScreen.screens.first
    case .mouse:
      return NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
    case .activeWindow:
      return NSScreen.main
    }
  }
}

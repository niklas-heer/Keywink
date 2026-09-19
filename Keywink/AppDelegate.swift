import Cocoa
import Defaults
import KeyboardShortcuts
import Settings
import Sparkle
import SwiftUI
import UserNotifications

let updateLocationIdentifier = "UpdateCheck"

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate,
  SPUStandardUserDriverDelegate,
  UNUserNotificationCenterDelegate,
  NSWindowDelegate
{
  var controller: Controller!

  let statusItem = StatusItem()
  let config = UserConfig()

  var state: UserState!
  private var updaterController: SPUStandardUpdaterController?

  lazy var settingsWindowController = SettingsWindowController(
    panes: [
      Settings.Pane(
        identifier: .general, title: "General",
        toolbarIcon: NSImage(named: NSImage.preferencesGeneralName)!,
        contentView: { GeneralPane().environmentObject(self.config) }
      ),
      Settings.Pane(
        identifier: .advanced, title: "Advanced",
        toolbarIcon: NSImage(named: NSImage.advancedName)!,
        contentView: {
          AdvancedPane().environmentObject(self.config)
        }),
      Settings.Pane(
        identifier: .statistics, title: "Statistics",
        toolbarIcon: NSImage(
          systemSymbolName: "chart.bar", accessibilityDescription: "Statistics")!,
        contentView: { StatisticsPane() }),
    ],
    style: .segmentedControl,
  )

  func applicationDidFinishLaunching(_: Notification) {

    guard
      ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    else { return }
    guard !isRunningTests() else { return }

    if Self.hasUpdateConfiguration(Bundle.main.infoDictionary ?? [:]) {
      updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    UNUserNotificationCenter.current().delegate = self

    NSApp.mainMenu = MainMenu()

    config.ensureAndLoad()
    state = UserState(userConfig: config)
    controller = Controller(userState: state, userConfig: config)

    statusItem.handlePreferences = {
      self.showSettings()
    }
    statusItem.handleAbout = {
      NSApp.orderFrontStandardAboutPanel(nil)
    }
    statusItem.handleReloadConfig = {
      self.config.reloadFromFile()
    }
    statusItem.handleRevealConfig = {
      NSWorkspace.shared.activateFileViewerSelecting([self.config.url])
    }
    statusItem.updateMenuTitle =
      updaterController == nil ? "Keywink Releases…" : "Check for Updates…"
    statusItem.handleCheckForUpdates = {
      if let updaterController = self.updaterController {
        updaterController.checkForUpdates(nil)
      } else {
        NSWorkspace.shared.open(URL(string: "https://github.com/niklas-heer/Keywink/releases")!)
      }
    }

    Task {
      for await value in Defaults.updates(.showMenuBarIcon) {
        if value {
          self.statusItem.enable()
        } else {
          self.statusItem.disable()
        }
      }
    }

    // Initialize status item according to current preference
    if Defaults[.showMenuBarIcon] {
      statusItem.enable()
    } else {
      statusItem.disable()
    }

    // Activation policy is managed solely by the Settings window

    registerGlobalShortcuts()
  }

  func activate() {
    if self.controller.window.isKeyWindow {
      switch Defaults[.reactivateBehavior] {
      case .hide:
        self.hide()
      case .reset:
        self.controller.userState.clear()
      case .nothing:
        return
      }
    } else if self.controller.window.isVisible {
      // should never happen as the window will self-hide when not key
      self.controller.window.makeKeyAndOrderFront(nil)
    } else {
      self.show()
    }
  }

  @MainActor
  public func registerGlobalShortcuts() {
    KeyboardShortcuts.removeAllHandlers()

    KeyboardShortcuts.onKeyDown(for: .activate) {
      self.activate()
    }

    for groupKey in Defaults[.groupShortcuts] {
      print("Registering shortcut for \(groupKey)")
      KeyboardShortcuts.onKeyDown(for: KeyboardShortcuts.Name("group-\(groupKey)")) {
        self.controller.openRootGroup(for: groupKey)
      }
    }
    if Defaults[.groupShortcuts].isEmpty && !KeyboardShortcuts.isEnabled(for: .activate) {
      showSettings()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    // Config saves automatically on changes
  }

  @IBAction
  func settingsMenuItemActionHandler(_: NSMenuItem) {
    showSettings()
  }

  func show() {
    controller.show()
  }

  func hide() {
    controller.hide()
  }

  // MARK: - Sparkle Gentle Reminders

  @objc var supportsGentleScheduledUpdateReminders: Bool {
    return true
  }

  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    // Do not change activation policy here; Settings drives visibility

    if !state.userInitiated {
      NSApp.dockTile.badgeLabel = "1"

      requestNotificationsAuthorizationIfNeeded { granted in
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Keywink Update Available"
        content.body = "Version \(update.displayVersionString) is now available"

        let request = UNNotificationRequest(
          identifier: updateLocationIdentifier, content: content,
          trigger: nil)
        UNUserNotificationCenter.current().add(request)
      }
    }
  }

  func standardUserDriverDidReceiveUserAttention(
    forUpdate update: SUAppcastItem
  ) {
    NSApp.dockTile.badgeLabel = ""

    UNUserNotificationCenter.current().removeDeliveredNotifications(
      withIdentifiers: [
        updateLocationIdentifier
      ])
  }

  func standardUserDriverWillFinishUpdateSession() {}

  // MARK: - UNUserNotificationCenter Delegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.notification.request.identifier
      == updateLocationIdentifier
      && response.actionIdentifier == UNNotificationDefaultActionIdentifier
    {
      updaterController?.checkForUpdates(nil)
    }
    completionHandler()
  }

  func isRunningTests() -> Bool {
    RuntimeEnvironment.isRunningTests
  }

  static func hasUpdateConfiguration(_ info: [String: Any]) -> Bool {
    guard let feed = info["SUFeedURL"] as? String,
      let url = URL(string: feed), url.scheme == "https", url.host?.isEmpty == false,
      let publicKey = info["SUPublicEDKey"] as? String,
      let keyData = Data(base64Encoded: publicKey), keyData.count == 32
    else { return false }
    return true
  }

  // MARK: - URL Scheme Handling

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      handleURL(url)
    }
  }

  private func handleURL(_ url: URL) {
    let action = URLSchemeHandler.parse(url)

    switch action {
    case .settings:
      showSettings()
    case .about:
      NSApp.orderFrontStandardAboutPanel(nil)
    case .configReload:
      config.reloadFromFile()
    case .configReveal:
      NSWorkspace.shared.selectFile(config.path, inFileViewerRootedAtPath: "")
    case .activate:
      activate()
    case .hide:
      hide()
    case .reset:
      state.clear()
    case .navigate(let keys, let execute):
      show()
      processKeys(keys, execute: execute)
    case .show:
      show()
    case .invalid:
      return
    }
  }

  private func processKeys(_ keys: [String], execute: Bool = true) {
    guard !keys.isEmpty else { return }

    controller.handleKey(keys[0], execute: execute)

    if keys.count > 1 {
      let remainingKeys = Array(keys.dropFirst())

      var delayMs = 100
      for key in remainingKeys {
        delay(delayMs) { [weak self] in
          self?.controller.handleKey(key, execute: execute)
        }
        delayMs += 100
      }
    }
  }

  // MARK: - Activation Policy: Only Settings Visibility Controls It

  private func showSettings() {
    // Behave like a normal app while Settings is open
    NSApp.setActivationPolicy(.regular)
    settingsWindowController.show()
    NSApp.activate(ignoringOtherApps: true)
    settingsWindowController.window?.delegate = self
  }

  // Revert to accessory when Settings window closes
  func windowWillClose(_ notification: Notification) {
    guard let win = notification.object as? NSWindow,
      win == settingsWindowController.window
    else { return }
    NSApp.setActivationPolicy(.accessory)
  }

  private func requestNotificationsAuthorizationIfNeeded(
    completion: @escaping (Bool) -> Void
  ) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .notDetermined:
        UNUserNotificationCenter.current().requestAuthorization(options: [
          .alert, .badge, .sound,
        ]) { granted, _ in
          DispatchQueue.main.async { completion(granted) }
        }
      case .authorized, .provisional, .ephemeral:
        DispatchQueue.main.async { completion(true) }
      case .denied:
        DispatchQueue.main.async { completion(false) }
      @unknown default:
        DispatchQueue.main.async { completion(false) }
      }
    }
  }
}

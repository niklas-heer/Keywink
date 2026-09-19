import Cocoa
import Defaults
import KeyboardShortcuts
import XCTest

@testable import Keywink

final class TopEdgeTests: XCTestCase {
  func testPanelCentersInNotchedDisplayVisibleFrame() {
    let layout = TopEdge.Layout.make(
      screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
      visibleFrame: NSRect(x: 0, y: 70, width: 1512, height: 874),
      itemCount: 7)
    XCTAssertEqual(layout.frame.midX, 756)
    XCTAssertEqual(layout.frame.midY, 507)
    XCTAssertEqual(layout.frame.width, 440)
    XCTAssertEqual(layout.frame.height, 288)
  }

  func testExternalDisplayRespectsNegativeCoordinatesAndDock() {
    let screen = NSRect(x: -1920, y: -200, width: 1920, height: 1080)
    let visible = NSRect(x: -1840, y: -200, width: 1840, height: 1055)
    let layout = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible,
      itemCount: 4)
    XCTAssertEqual(layout.frame.midX, visible.midX)
    XCTAssertEqual(layout.frame.midY, visible.midY)
    XCTAssertTrue(visible.contains(layout.frame))
  }

  func testLongGroupsStayBoundedOnNarrowDisplays() {
    let screen = NSRect(x: 100, y: 100, width: 380, height: 700)
    let visible = NSRect(x: 100, y: 150, width: 380, height: 625)
    let small = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible, itemCount: 0)
    let large = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible, itemCount: 300)
    XCTAssertTrue(visible.contains(large.frame))
    XCTAssertEqual(large.frame.width, 340)
    XCTAssertGreaterThan(large.frame.height, small.frame.height)
    XCTAssertEqual(large.frame.height, 390)
    XCTAssertEqual(large.frame.midY, small.frame.midY)
  }

  func testTopEdgeStoredValueUsesKeyGuideVisibleName() {
    XCTAssertEqual(Theme.topEdge.rawValue, "topEdge")
    XCTAssertEqual(Theme.name(.topEdge), "Key Guide")
  }

  @MainActor
  func testShortcutLabelUsesHyperSymbolAndPreservesOtherModifiers() {
    let hyper = KeyboardShortcuts.Shortcut(.g, modifiers: [.control, .option, .shift, .command])
    XCTAssertEqual(TopEdge.shortcutLabel(hyper), "✦ G")
    let commandShift = KeyboardShortcuts.Shortcut(.g, modifiers: [.command, .shift])
    XCTAssertEqual(TopEdge.shortcutLabel(commandShift), commandShift.description)
  }

  @MainActor
  func testPanelPresentsNavigatesAndDismisses() throws {
    let screen = try XCTUnwrap(NSScreen.main)
    let originalTheme = Defaults[.theme]
    Defaults[.theme] = .topEdge
    defer { Defaults[.theme] = originalTheme }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let config = UserConfig(
      defaultDirectoryResolver: { directory.path },
      configDirectoryReader: { directory.path }, configDirectoryWriter: { _ in })
    let data = Data(
      """
      {"actions":[
        {"key":"o","type":"group","label":"Open","iconPath":"square.grid.2x2","actions":[
          {"key":"b","type":"url","label":"Browser","value":"https://example.com","iconPath":"safari"},
          {"key":"r","type":"command","label":"🚀 Release","value":"mise run release"},
          {"key":"n","type":"group","label":"Nested","actions":[
            {"key":"d","type":"group","label":"Deep","actions":[
              {"key":"x","type":"command","label":"No-op","value":":"}
            ]}
          ]}
        ]},
        {"key":"t","type":"application","label":"Terminal","value":"/System/Applications/Utilities/Terminal.app"},
        {"key":"b","type":"command","label":"⚙️ Build","value":"mise run build","iconPath":"hammer"},
        {"key":"d","type":"folder","label":"📁 Dotfiles","value":"/tmp"},
        {"key":"m","type":"group","label":"Media","actions":[]},
        {"key":"w","type":"group","label":"Windows","actions":[]},
        {"key":"n","type":"group","label":"Notes","actions":[]},
        {"key":"s","type":"group","label":"System","actions":[]}
      ]}
      """.utf8)
    try data.write(to: config.url)
    config.ensureAndLoad()
    let state = UserState(userConfig: config)
    let controller = Controller(userState: state, userConfig: config)
    settle()
    let window = try XCTUnwrap(controller.window as? TopEdge.Window)
    defer { window.orderOut(nil) }
    let shown = expectation(description: "panel shown")
    window.show(on: screen) { shown.fulfill() }
    wait(for: [shown], timeout: 2)
    XCTAssertTrue(window.isVisible)
    XCTAssertEqual(window.frame.midX, screen.visibleFrame.midX, accuracy: 0.5)
    XCTAssertEqual(window.frame.midY, screen.visibleFrame.midY, accuracy: 0.5)
    XCTAssertEqual(window.frame.width, 440)
    let rootWidth = window.frame.width
    let rootCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
    let rootHeight = window.frame.height

    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      window.appearance = NSAppearance(named: appearance)
      settle()
      try attach(window: window, name: "Key Guide — Root — \(appearance.rawValue)")
    }

    controller.handleKey("o")
    settle()
    XCTAssertEqual(state.currentGroup?.label, "Open")
    XCTAssertLessThan(window.frame.height, rootHeight)
    XCTAssertEqual(window.frame.width, rootWidth)
    XCTAssertEqual(window.frame.midX, rootCenter.x, accuracy: 0.5)
    XCTAssertEqual(window.frame.midY, rootCenter.y, accuracy: 0.5)

    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      window.appearance = NSAppearance(named: appearance)
      settle()
      try attach(window: window, name: "Key Guide — Group — \(appearance.rawValue)")
    }

    let backspace = try XCTUnwrap(
      NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, characters: "",
        charactersIgnoringModifiers: "", isARepeat: false,
        keyCode: KeyHelpers.backspace.rawValue))
    controller.handleKey("n")
    controller.handleKey("d")
    settle()
    XCTAssertEqual(state.keyPath, ["o", "n", "d"])
    controller.keyDown(with: backspace)
    XCTAssertEqual(state.keyPath, ["o", "n"])
    controller.keyDown(with: backspace)
    XCTAssertEqual(state.keyPath, ["o"])
    controller.keyDown(with: backspace)
    settle()
    XCTAssertTrue(state.navigationPath.isEmpty)
    XCTAssertNil(state.currentGroup)
    XCTAssertEqual(window.frame.width, rootWidth)
    XCTAssertEqual(window.frame.midX, rootCenter.x, accuracy: 0.5)
    XCTAssertEqual(window.frame.midY, rootCenter.y, accuracy: 0.5)
    XCTAssertEqual(window.frame.height, rootHeight)

    controller.keyDown(with: backspace)
    XCTAssertTrue(state.navigationPath.isEmpty, "Backspace at the root is harmless")
    XCTAssertTrue(window.isVisible)

    controller.openRootGroup(for: "o")
    controller.handleKey("n")
    controller.handleKey("d")
    controller.openRootGroup(for: "m")
    XCTAssertEqual(state.keyPath, ["m"], "A direct group shortcut replaces the full path")
    controller.openRootGroup(for: "o")
    settle()
    XCTAssertEqual(state.currentGroup?.label, "Open")
    // A config edit must invalidate the stored Group value, both visually and for execution.
    config.root = Group(key: nil, actions: [])
    settle()
    XCTAssertTrue(state.navigationPath.isEmpty)
    XCTAssertNil(state.currentGroup)

    let hidden = expectation(description: "panel dismissed")
    window.hide { hidden.fulfill() }
    wait(for: [hidden], timeout: 2)
    XCTAssertFalse(window.isVisible)

    let shownAgain = expectation(description: "new presentation survives old dismissal")
    window.show(on: screen)
    window.hide()
    window.show(on: screen) { shownAgain.fulfill() }
    wait(for: [shownAgain], timeout: 2)
    settle()
    XCTAssertTrue(window.isVisible)
    XCTAssertEqual(window.alphaValue, 1, accuracy: 0.01)
  }

  @MainActor
  func testUsageTracksNavigationAndKeepsTheSourceApplicationForEachSession() throws {
    let originalTheme = Defaults[.theme]
    let originalTracking = Defaults[.trackUsage]
    Defaults[.theme] = .topEdge
    Defaults[.trackUsage] = true
    defer {
      Defaults[.theme] = originalTheme
      Defaults[.trackUsage] = originalTracking
    }

    let suite = "KeywinkUsageIntegrationTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let usage = UsageStatistics(defaults: defaults)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let config = UserConfig(
      defaultDirectoryResolver: { directory.path },
      configDirectoryReader: { directory.path }, configDirectoryWriter: { _ in })
    let fixture = Data(
      """
      {"actions":[
        {"key":"o","type":"group","label":"Open","actions":[
          {"key":"n","type":"group","label":"Nested","actions":[
            {"key":"d","type":"group","label":"Deep","actions":[]}
          ]}
        ]},
        {"key":"m","type":"group","label":"More","actions":[
          {"key":"x","type":"command","label":"No-op","value":":"}
        ]}
      ]}
      """.utf8)
    try fixture.write(to: config.url)
    config.ensureAndLoad()
    let state = UserState(userConfig: config)
    var source = (id: "test.editor", name: "Editor")
    let controller = Controller(
      userState: state, userConfig: config, usage: usage, sourceApplication: { source })
    settle()
    defer { controller.window.orderOut(nil) }

    controller.show()
    settle()
    controller.show()
    XCTAssertEqual(usage.totalOpenings, 1, "Showing an already visible guide is not another open")
    XCTAssertEqual(usage.groupViews, 0, "The root is counted as an opening, not a group view")
    controller.openRootGroup(for: "o")
    controller.handleKey("n")
    controller.handleKey("d")
    controller.goBack()
    XCTAssertEqual(state.keyPath, ["o", "n"])
    XCTAssertEqual(usage.groupViews, 4)
    XCTAssertEqual(usage.count(path: ["o", "n"], appID: source.id), 2)
    controller.handleKey("missing")
    controller.openRootGroup(for: "missing")
    XCTAssertEqual(usage.groupViews, 4, "Unmatched keys do not create views")

    source = (id: "test.browser", name: "Browser")
    controller.openRootGroup(for: "m")
    XCTAssertEqual(state.sourceAppID, "test.editor", "Navigation keeps the opening app context")
    XCTAssertEqual(usage.groupViews, 5)
    controller.handleKey("x", execute: false)
    XCTAssertEqual(usage.actionUses, 0, "Previewing an action does not count as choosing it")
    controller.handleKey("x")
    settle()
    XCTAssertFalse(controller.window.isVisible)
    XCTAssertEqual(usage.actionUses, 1)
    XCTAssertEqual(usage.count(path: ["m", "x"], appID: "test.editor"), 1)

    controller.openRootGroup(for: "o")
    settle()
    XCTAssertEqual(state.sourceAppID, "test.browser", "A new session captures the new source app")
    XCTAssertEqual(usage.totalOpenings, 2)
    XCTAssertEqual(usage.groupViews, 6)
    Defaults[.trackUsage] = false
    controller.handleKey("n")
    controller.goBack()
    controller.openRootGroup(for: "m")
    controller.handleKey("x")
    settle()
    XCTAssertEqual(usage.groupViews, 6)
    XCTAssertEqual(usage.actionUses, 1)
    controller.show()
    settle()
    XCTAssertEqual(usage.totalOpenings, 2, "Tracking off also pauses opening counts")
    controller.hide()
    settle()

    Defaults[.trackUsage] = true
    state.isShowingRefreshState = true
    controller.show()
    settle()
    XCTAssertEqual(usage.totalOpenings, 2, "Configuration refresh feedback is not a user opening")
    controller.hide()
    settle()
    controller.openRootGroup(for: "m")
    settle()
    XCTAssertEqual(usage.totalOpenings, 3)
    XCTAssertEqual(usage.groupViews, 7)

    let editor = try XCTUnwrap(usage.applications.first { $0.appID == "test.editor" })
    let browser = try XCTUnwrap(usage.applications.first { $0.appID == "test.browser" })
    XCTAssertEqual(editor.openings, 1)
    XCTAssertEqual(editor.groupViews, 5)
    XCTAssertEqual(editor.actionUses, 1)
    XCTAssertEqual(browser.openings, 2)
    XCTAssertEqual(browser.groupViews, 2)
    XCTAssertEqual(browser.actionUses, 0)
  }

  private func settle() {
    let settled = expectation(description: "UI settled")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
    wait(for: [settled], timeout: 2)
  }

  @MainActor
  private func attach(window: NSWindow, name: String) throws {
    let view = try XCTUnwrap(window.contentView)
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let image = NSImage(size: view.bounds.size)
    image.addRepresentation(bitmap)
    let attachment = XCTAttachment(image: image)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

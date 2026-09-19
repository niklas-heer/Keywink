import Cocoa
import Defaults
import XCTest

@testable import Leader_Key

final class TopEdgeTests: XCTestCase {
  func testPanelCentersInNotchedDisplayVisibleFrame() {
    let layout = TopEdge.Layout.make(
      screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
      visibleFrame: NSRect(x: 0, y: 70, width: 1512, height: 874),
      itemCount: 7)
    XCTAssertEqual(layout.frame.midX, 756)
    XCTAssertEqual(layout.frame.midY, 507)
    XCTAssertEqual(layout.frame.width, 560)
    XCTAssertEqual(layout.columns, 2)
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
    let screen = NSRect(x: 100, y: 100, width: 500, height: 700)
    let visible = NSRect(x: 100, y: 150, width: 500, height: 625)
    let small = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible, itemCount: 0)
    let large = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible, itemCount: 300,
      hasBreadcrumb: true)
    XCTAssertTrue(visible.contains(large.frame))
    XCTAssertEqual(large.columns, 2)
    XCTAssertGreaterThan(large.frame.height, small.frame.height)
    XCTAssertEqual(large.frame.height, 316)
    XCTAssertEqual(large.frame.midY, small.frame.midY)
  }

  func testTopEdgeStoredValueUsesKeyGuideVisibleName() {
    XCTAssertEqual(Theme.topEdge.rawValue, "topEdge")
    XCTAssertEqual(Theme.name(.topEdge), "Key Guide")
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
          {"key":"r","type":"command","label":"🚀 Release","value":"mise run release"}
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
    XCTAssertEqual(window.frame.width, 560)
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
    controller.keyDown(with: backspace)
    settle()
    XCTAssertTrue(state.navigationPath.isEmpty)
    XCTAssertNil(state.currentGroup)
    XCTAssertEqual(window.frame.width, rootWidth)
    XCTAssertEqual(window.frame.midX, rootCenter.x, accuracy: 0.5)
    XCTAssertEqual(window.frame.midY, rootCenter.y, accuracy: 0.5)
    XCTAssertEqual(window.frame.height, rootHeight)

    controller.handleKey("o")
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

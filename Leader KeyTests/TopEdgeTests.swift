import Cocoa
import Defaults
import SwiftUI
import XCTest

@testable import Leader_Key

final class TopEdgeTests: XCTestCase {
  func testNotchedDisplayKeepsContentBelowCameraAndMenuBar() {
    let layout = TopEdge.Layout.make(
      screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
      visibleFrame: NSRect(x: 0, y: 70, width: 1512, height: 874),
      safeTop: 38, notchWidth: 180, itemCount: 7)
    XCTAssertEqual(layout.frame.midX, 756)
    XCTAssertEqual(layout.frame.maxY, 944)
    XCTAssertEqual(layout.neckWidth, 180)
    XCTAssertEqual(layout.columns, 3)
  }

  func testExternalDisplayRespectsNegativeCoordinatesAndDock() {
    let screen = NSRect(x: -1920, y: -200, width: 1920, height: 1080)
    let visible = NSRect(x: -1840, y: -200, width: 1840, height: 1055)
    let layout = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible,
      safeTop: 0, notchWidth: 0, itemCount: 4)
    XCTAssertEqual(layout.frame.midX, screen.midX)
    XCTAssertEqual(layout.frame.maxY, visible.maxY - 10)
    XCTAssertTrue(visible.contains(layout.frame))
    XCTAssertEqual(layout.neckWidth, 0)
  }

  func testLongGroupsStayBoundedOnNarrowDisplays() {
    let screen = NSRect(x: 100, y: 100, width: 500, height: 700)
    let visible = NSRect(x: 100, y: 150, width: 500, height: 625)
    let small = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible, safeTop: 0, notchWidth: 0, itemCount: 0)
    let large = TopEdge.Layout.make(
      screenFrame: screen, visibleFrame: visible, safeTop: 0, notchWidth: 0, itemCount: 300)
    XCTAssertTrue(visible.contains(large.frame))
    XCTAssertEqual(large.columns, 2)
    XCTAssertGreaterThan(large.frame.height, small.frame.height)
    XCTAssertLessThan(large.frame.height, 300)
    XCTAssertEqual(large.frame.maxY, small.frame.maxY)
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
        {"key":"o","type":"group","label":"Open","actions":[
          {"key":"b","type":"url","label":"Browser","value":"https://example.com"}
        ]},
        {"key":"t","type":"application","label":"Terminal","value":"/System/Applications/Utilities/Terminal.app"},
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
    XCTAssertLessThanOrEqual(window.frame.maxY, screen.visibleFrame.maxY)
    let rootHeight = window.frame.height

    let liveContent = window.contentView
    let liveFrame = window.frame
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
      window.appearance = NSAppearance(named: appearance)
      settle()
      let view = try XCTUnwrap(window.contentView)
      let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
      view.cacheDisplay(in: view.bounds, to: bitmap)
      let image = NSImage(size: view.bounds.size)
      image.addRepresentation(bitmap)
      let attachment = XCTAttachment(image: image)
      attachment.name = "Top Edge — \(appearance.rawValue)"
      attachment.lifetime = .keepAlways
      add(attachment)
      // Render the same production view with a simulated camera bridge on this display.
      let preview = TopEdge.Presentation()
      preview.neckWidth = 180
      let notchedView = NSHostingView(
        rootView: TopEdge.MainView(
          presentation: preview, choose: { _ in }, reset: {}, dismiss: {}
        ).environmentObject(state).environmentObject(config))
      window.contentView = notchedView
      window.setFrame(
        NSRect(
          x: liveFrame.minX, y: liveFrame.minY - 14, width: liveFrame.width,
          height: liveFrame.height + 14),
        display: true)
      settle()
      let notchBitmap = try XCTUnwrap(
        notchedView.bitmapImageRepForCachingDisplay(in: notchedView.bounds))
      notchedView.cacheDisplay(in: notchedView.bounds, to: notchBitmap)
      let notchImage = NSImage(size: notchedView.bounds.size)
      notchImage.addRepresentation(notchBitmap)
      let notchAttachment = XCTAttachment(image: notchImage)
      notchAttachment.name = "Top Edge notch — \(appearance.rawValue)"
      notchAttachment.lifetime = .keepAlways
      add(notchAttachment)
      window.contentView = liveContent
      window.setFrame(liveFrame, display: true)
    }

    controller.handleKey("o")
    settle()
    XCTAssertEqual(state.currentGroup?.label, "Open")
    XCTAssertLessThan(window.frame.height, rootHeight)
    XCTAssertLessThanOrEqual(window.frame.maxY, screen.visibleFrame.maxY)
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
}

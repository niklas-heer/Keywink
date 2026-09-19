import AppKit
import Carbon.HIToolbox
import Combine
import Defaults
import KeyboardShortcuts
import XCTest

@testable import Keywink

class KeyboardLayoutTests: XCTestCase {
  var controller: Controller!
  var cancellables: Set<AnyCancellable>!
  var userState: UserState!
  var userConfig: UserConfig!
  var originalForceEnglishKeyboardLayout: Bool!

  override func setUp() {
    super.setUp()
    cancellables = Set<AnyCancellable>()
    originalForceEnglishKeyboardLayout = Defaults[.forceEnglishKeyboardLayout]

    // Create test instances
    userConfig = UserConfig()
    userState = UserState(userConfig: userConfig)
    controller = Controller(userState: userState, userConfig: userConfig)

    // Reset to default state
    Defaults[.forceEnglishKeyboardLayout] = false
  }

  override func tearDown() {
    Defaults[.forceEnglishKeyboardLayout] = originalForceEnglishKeyboardLayout
    cancellables = nil
    controller = nil
    userState = nil
    userConfig = nil
    super.tearDown()
  }

  // Helper to create fake NSEvent for testing
  private func fakeEvent(
    keyCode: UInt16, characters: String, charactersIgnoringModifiers: String,
    modifierFlags: NSEvent.ModifierFlags = []
  ) -> NSEvent {
    // This is a simplified mock - in real implementation we'd need to create a proper NSEvent
    // For now, we'll test the logic indirectly through Controller methods
    return NSEvent.keyEvent(
      with: .keyDown,
      location: NSPoint.zero,
      modifierFlags: modifierFlags,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: charactersIgnoringModifiers,
      isARepeat: false,
      keyCode: keyCode
    )!
  }

  func testAZERTYLayoutWithForceEnglishDisabled() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Physical A key on AZERTY keyboard produces "q"
    let azertyAKey = fakeEvent(keyCode: 0x00, characters: "q", charactersIgnoringModifiers: "q")
    let result = controller.charForEvent(azertyAKey)

    XCTAssertEqual(result, "q", "Should respect AZERTY layout and return 'q' for physical A key")
  }

  func testAZERTYLayoutWithForceEnglishEnabled() {
    Defaults[.forceEnglishKeyboardLayout] = true

    // Physical A key on AZERTY keyboard - should force to English "a"
    let azertyAKey = fakeEvent(keyCode: 0x00, characters: "q", charactersIgnoringModifiers: "q")
    let result = controller.charForEvent(azertyAKey)

    XCTAssertEqual(result, "a", "Should force English layout and return 'a' for physical A key")
  }

  func testColemakLayoutWithForceEnglishDisabled() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Physical S key on Colemak produces "r"
    let colemakSKey = fakeEvent(keyCode: 0x01, characters: "r", charactersIgnoringModifiers: "r")
    let result = controller.charForEvent(colemakSKey)

    XCTAssertEqual(result, "r", "Should respect Colemak layout and return 'r' for physical S key")
  }

  func testColemakLayoutWithForceEnglishEnabled() {
    Defaults[.forceEnglishKeyboardLayout] = true

    // Physical S key on Colemak - should force to English "s"
    let colemakSKey = fakeEvent(keyCode: 0x01, characters: "r", charactersIgnoringModifiers: "r")
    let result = controller.charForEvent(colemakSKey)

    XCTAssertEqual(result, "s", "Should force English layout and return 's' for physical S key")
  }

  func testCaseSensitivityWithLayout() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Test lowercase
    let lowerR = fakeEvent(keyCode: 0x0F, characters: "r", charactersIgnoringModifiers: "r")
    let lowerResult = controller.charForEvent(lowerR)
    XCTAssertEqual(lowerResult, "r", "Should return lowercase 'r'")

    // Test uppercase with shift
    let upperR = fakeEvent(
      keyCode: 0x0F, characters: "R", charactersIgnoringModifiers: "R", modifierFlags: .shift)
    let upperResult = controller.charForEvent(upperR)
    XCTAssertEqual(upperResult, "R", "Should return uppercase 'R' with shift")

    XCTAssertNotEqual(lowerResult, upperResult, "Lowercase and uppercase should be different")
  }

  func testCaseSensitivityWithForceEnglish() {
    Defaults[.forceEnglishKeyboardLayout] = true

    // Test lowercase
    let lowerR = fakeEvent(keyCode: 0x0F, characters: "r", charactersIgnoringModifiers: "r")
    let lowerResult = controller.charForEvent(lowerR)
    XCTAssertEqual(lowerResult, "r", "Should return lowercase 'r' in force English mode")

    // Test uppercase with shift
    let upperR = fakeEvent(
      keyCode: 0x0F, characters: "R", charactersIgnoringModifiers: "R", modifierFlags: .shift)
    let upperResult = controller.charForEvent(upperR)
    XCTAssertEqual(upperResult, "R", "Should return uppercase 'R' with shift in force English mode")

    XCTAssertNotEqual(
      lowerResult, upperResult, "Lowercase and uppercase should be different in force English mode")
  }

  func testSpecialKeysAlwaysUseKeyMaps() {
    Defaults[.forceEnglishKeyboardLayout] = false

    // Arrow keys should always use KeyMaps regardless of layout setting
    let leftArrow = fakeEvent(keyCode: 0x7B, characters: "", charactersIgnoringModifiers: "")
    let result = controller.charForEvent(leftArrow)

    // Should return the KeyMaps entry for left arrow
    XCTAssertEqual(result, "←", "Special keys should always use KeyMaps")
  }
}

final class ShortcutRecorderTests: XCTestCase {
  @MainActor
  func testRecorderSurvivesFieldEditorRestartsAndCapturesHyperShortcuts() throws {
    var changes: [KeyboardShortcuts.Shortcut?] = []
    let recorder = KeyboardShortcuts.RecorderCocoa(shortcut: nil) { shortcut in
      changes.append(shortcut)
    }
    recorder.conflictPolicy = .allowAll

    let stackView = NSStackView(views: [recorder])
    stackView.orientation = .vertical
    stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
      styleMask: [.titled],
      backing: .buffered,
      defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = stackView
    let originalPolicy = NSApp.activationPolicy()
    NSApp.setActivationPolicy(.regular)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    window.makeKeyAndOrderFront(nil)
    window.layoutIfNeeded()
    drainMainRunLoop()
    defer {
      window.close()
      NSApp.setActivationPolicy(originalPolicy)
    }

    let inactivePlaceholder = recorder.placeholderString

    try focus(recorder, in: window, inactivePlaceholder: inactivePlaceholder)
    sendHyperKey(.w, keyCode: kVK_ANSI_W, to: window)
    drainMainRunLoop()
    XCTAssertEqual(changes, [KeyboardShortcuts.Shortcut(.w, modifiers: hyperModifiers)])
    XCTAssertEqual(recorder.shortcut, KeyboardShortcuts.Shortcut(.w, modifiers: hyperModifiers))

    try focus(recorder, in: window, inactivePlaceholder: inactivePlaceholder)
    sendHyperKey(.b, keyCode: kVK_ANSI_B, to: window)
    drainMainRunLoop()
    XCTAssertEqual(
      changes,
      [
        KeyboardShortcuts.Shortcut(.w, modifiers: hyperModifiers),
        KeyboardShortcuts.Shortcut(.b, modifiers: hyperModifiers),
      ])
    XCTAssertEqual(recorder.shortcut, KeyboardShortcuts.Shortcut(.b, modifiers: hyperModifiers))

    try focus(recorder, in: window, inactivePlaceholder: inactivePlaceholder)
    sendKey(.escape, keyCode: kVK_Escape, modifiers: [], to: window)
    drainMainRunLoop()

    XCTAssertNil(recorder.currentEditor(), "Escape should cancel recording")
    XCTAssertEqual(recorder.placeholderString, inactivePlaceholder)
    XCTAssertEqual(changes.count, 2, "Cancelling must not emit a shortcut change")
    XCTAssertEqual(recorder.shortcut, KeyboardShortcuts.Shortcut(.b, modifiers: hyperModifiers))
  }

  private let hyperModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

  @MainActor
  private func focus(
    _ recorder: KeyboardShortcuts.RecorderCocoa,
    in window: NSWindow,
    inactivePlaceholder: String?
  ) throws {
    let clickLocation = recorder.convert(
      NSPoint(x: recorder.bounds.midX, y: recorder.bounds.midY), to: nil)

    let mouseDown = try XCTUnwrap(
      NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: clickLocation,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1))
    let mouseUp = try XCTUnwrap(
      NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: clickLocation,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 0))
    // sendEvent(mouseDown) can enter AppKit mouse tracking. Deliver mouseUp
    // in event-tracking mode so that nested run loop can exit on CI.
    RunLoop.current.perform(inModes: [.default, .eventTracking, .common]) {
      NSApp.sendEvent(mouseUp)
    }
    NSApp.sendEvent(mouseDown)

    // macOS 26 and later may end and restart editing after the click and placeholder update.
    let editor = try waitForEditor(in: recorder)
    XCTAssertTrue(window.firstResponder === editor)
    XCTAssertNotEqual(
      recorder.placeholderString, inactivePlaceholder,
      "The recorder stopped during AppKit's field-editor restart")
  }

  @MainActor
  private func waitForEditor(
    in recorder: KeyboardShortcuts.RecorderCocoa,
    timeout: TimeInterval = 2
  ) throws -> NSText {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      drainMainRunLoop()
      if let editor = recorder.currentEditor() {
        return editor
      }
    }
    return try XCTUnwrap(recorder.currentEditor(), "Recorder did not start editing after the click")
  }

  @MainActor
  private func sendHyperKey(
    _ key: KeyboardShortcuts.Key,
    keyCode: Int,
    to window: NSWindow
  ) {
    sendKey(key, keyCode: keyCode, modifiers: hyperModifiers, to: window)
  }

  @MainActor
  private func sendKey(
    _ key: KeyboardShortcuts.Key,
    keyCode: Int,
    modifiers: NSEvent.ModifierFlags,
    to window: NSWindow
  ) {
    let character = key == .escape ? "\u{1B}" : key == .w ? "w" : "b"
    let event = NSEvent.keyEvent(
      with: .keyDown,
      location: .zero,
      modifierFlags: modifiers,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      characters: character,
      charactersIgnoringModifiers: character,
      isARepeat: false,
      keyCode: UInt16(keyCode))!
    NSApp.sendEvent(event)
  }

  @MainActor
  private func drainMainRunLoop() {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
  }
}

final class CommandRunnerTests: XCTestCase {
  func testLargeFailingCommandDoesNotBlockMainQueue() throws {
    let mainQueueAdvanced = expectation(description: "main queue advanced")
    let commandCompleted = expectation(description: "command completed")
    var executionResult: Swift.Result<CommandRunner.Execution, Error>?

    DispatchQueue.main.async {
      CommandRunner.execute(
        "sleep 0.5; /usr/bin/yes x | /usr/bin/head -c 262144; "
          + "printf 'intentional failure\\n' >&2; exit 23"
      ) { result in
        XCTAssertTrue(Thread.isMainThread)
        executionResult = result
        commandCompleted.fulfill()
      }

      DispatchQueue.main.async {
        XCTAssertNil(executionResult, "The command should still be running")
        mainQueueAdvanced.fulfill()
      }
    }

    wait(for: [mainQueueAdvanced], timeout: 0.25)
    wait(for: [commandCompleted], timeout: 5)

    let execution = try XCTUnwrap(executionResult).get()
    XCTAssertEqual(execution.terminationStatus, 23)
    XCTAssertEqual(execution.standardOutput.count, 262144)
    XCTAssertEqual(String(data: execution.standardError, encoding: .utf8), "intentional failure\n")
  }
}

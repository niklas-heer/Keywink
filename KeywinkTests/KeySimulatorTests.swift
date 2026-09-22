import Carbon.HIToolbox
import XCTest

@testable import Keywink

final class KeySimulatorTests: XCTestCase {
  func testParsesNamedModifiersAndKeys() throws {
    let shortcut = try KeySimulator.parse("cmd+shift+4")
    XCTAssertEqual(shortcut.keyCode, CGKeyCode(kVK_ANSI_4))
    XCTAssertEqual(shortcut.flags, [.maskCommand, .maskShift])

    let spaced = try KeySimulator.parse("Control Option Space")
    XCTAssertEqual(spaced.keyCode, CGKeyCode(kVK_Space))
    XCTAssertEqual(spaced.flags, [.maskControl, .maskAlternate])

    // "delete" follows the configuration's key names: it is the forward delete key.
    let dashed = try KeySimulator.parse("ctrl-alt-delete")
    XCTAssertEqual(dashed.keyCode, CGKeyCode(kVK_ForwardDelete))
    XCTAssertEqual(dashed.flags, [.maskControl, .maskAlternate])
    XCTAssertEqual(try KeySimulator.parse("cmd+backspace").keyCode, CGKeyCode(kVK_Delete))
  }

  func testParsesGlyphsAndUppercaseImpliesShift() throws {
    let glyphs = try KeySimulator.parse("⌘⇧T")
    XCTAssertEqual(glyphs.keyCode, CGKeyCode(kVK_ANSI_T))
    XCTAssertEqual(glyphs.flags, [.maskCommand, .maskShift])

    let hyper = try KeySimulator.parse("hyper+k")
    XCTAssertEqual(hyper.keyCode, CGKeyCode(kVK_ANSI_K))
    XCTAssertEqual(hyper.flags, [.maskCommand, .maskShift, .maskAlternate, .maskControl])

    let bare = try KeySimulator.parse("f12")
    XCTAssertEqual(bare.keyCode, CGKeyCode(kVK_F12))
    XCTAssertEqual(bare.flags, [])
  }

  func testParsesPunctuationKeysIncludingSeparators() throws {
    XCTAssertEqual(try KeySimulator.parse("cmd+-").keyCode, CGKeyCode(kVK_ANSI_Minus))
    XCTAssertEqual(try KeySimulator.parse("cmd++").keyCode, CGKeyCode(kVK_ANSI_Equal))
    XCTAssertEqual(try KeySimulator.parse("cmd+,").keyCode, CGKeyCode(kVK_ANSI_Comma))
    XCTAssertEqual(try KeySimulator.parse("cmd+return").keyCode, CGKeyCode(kVK_Return))
  }

  func testRejectsMalformedShortcuts() {
    XCTAssertThrowsError(try KeySimulator.parse("")) {
      XCTAssertEqual($0 as? KeySimulator.ParseError, .empty)
    }
    XCTAssertThrowsError(try KeySimulator.parse("cmd+shift")) {
      XCTAssertEqual($0 as? KeySimulator.ParseError, .missingKey)
    }
    XCTAssertThrowsError(try KeySimulator.parse("cmd+a+b")) {
      XCTAssertEqual($0 as? KeySimulator.ParseError, .multipleKeys)
    }
    XCTAssertThrowsError(try KeySimulator.parse("cmd+bogus")) {
      XCTAssertEqual($0 as? KeySimulator.ParseError, .unknownKey("bogus"))
    }
  }

  func testChunksTextForUnicodeTyping() {
    XCTAssertEqual(KeySimulator.chunks(of: "", size: 3), [])
    XCTAssertEqual(KeySimulator.chunks(of: "héllo wörld", size: 4), ["héll", "o wö", "rld"])
  }

  func testValidatorFlagsInvalidShortcutsAndEmptyText() {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "a", type: .shortcut, value: "cmd+bogus")),
        .action(Action(key: "b", type: .shortcut, value: "cmd+shift+4")),
        .action(Action(key: "c", type: .text, value: "")),
        .action(Action(key: "d", type: .text, value: "Hello")),
      ])
    let errors = ConfigValidator.validate(group: root)
    XCTAssertEqual(errors.map(\.path), [[0], [2]])
    XCTAssertTrue(errors.allSatisfy { $0.type == .invalidValue })
  }

  func testNewTypesRoundTripThroughJSON() throws {
    let root = Group(
      key: nil,
      actions: [
        .action(Action(key: "t", type: .text, label: "Sign-off", value: "Best,\nNiklas")),
        .action(Action(key: "s", type: .shortcut, value: "cmd+shift+4")),
      ])
    let data = try JSONEncoder().encode(root)
    let decoded = try JSONDecoder().decode(Group.self, from: data)
    XCTAssertEqual(try JSONEncoder().encode(decoded), data)
    guard case .action(let text) = decoded.actions[0],
      case .action(let shortcut) = decoded.actions[1]
    else { return XCTFail("expected two actions") }
    XCTAssertEqual(text.type, .text)
    XCTAssertEqual(text.value, "Best,\nNiklas")
    XCTAssertEqual(text.bestGuessDisplayName, "Best,")
    XCTAssertEqual(shortcut.type, .shortcut)
    XCTAssertEqual(shortcut.bestGuessDisplayName, "cmd+shift+4")
  }
}

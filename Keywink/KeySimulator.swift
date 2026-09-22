import ApplicationServices
import Carbon.HIToolbox
import Cocoa

/// Types text and presses key combinations in the frontmost application through
/// synthetic keyboard events. macOS only delivers those when Keywink has Accessibility
/// permission, so callers check `isTrusted(prompt:)` first.
enum KeySimulator {
  struct Shortcut: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
  }

  enum ParseError: Error, Equatable {
    case empty
    case missingKey
    case multipleKeys
    case unknownKey(String)

    var message: String {
      switch self {
      case .empty: return "Shortcut is empty"
      case .missingKey: return "Shortcut needs a key besides the modifiers"
      case .multipleKeys: return "Shortcut may contain only one key"
      case .unknownKey(let key): return "Unknown key '\(key)'"
      }
    }
  }

  /// Parses "cmd+shift+4", "⌘⇧4", "ctrl-alt-delete", or "command space".
  static func parse(_ text: String) throws -> Shortcut {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ParseError.empty }

    var tokens: [String] = []
    if trimmed.count > 1, trimmed.contains(where: { "+- ".contains($0) }),
      trimmed.contains(where: { !"+- ".contains($0) })
    {
      // A trailing separator character is the key itself, e.g. "cmd++" or "shift+-".
      var current = ""
      for character in trimmed {
        if "+- ".contains(character), !current.isEmpty {
          tokens.append(current)
          current = ""
        } else if "+- ".contains(character), current.isEmpty, tokens.isEmpty {
          continue
        } else {
          current.append(character)
        }
      }
      if !current.isEmpty { tokens.append(current) }
      if tokens.count < 2, let last = trimmed.last, "+- ".contains(last) {
        tokens.append(String(last))
      }
    } else {
      tokens = [trimmed]
    }

    var flags: CGEventFlags = []
    var resolvedCode: CGKeyCode?
    for token in tokens {
      if let modifier = modifiers[token.lowercased()] {
        flags.insert(modifier)
        continue
      }
      // Glyph-only forms such as "⌘⇧T" arrive as one token.
      var rest = token
      while let first = rest.first, let modifier = modifiers[String(first)] {
        flags.insert(modifier)
        rest.removeFirst()
      }
      if rest.isEmpty { continue }
      guard let code = keyCode(for: rest) else { throw ParseError.unknownKey(rest) }
      guard resolvedCode == nil else { throw ParseError.multipleKeys }
      resolvedCode = code
      if rest.count == 1, let scalar = rest.unicodeScalars.first, scalar.properties.isUppercase {
        flags.insert(.maskShift)
      }
    }
    guard let code = resolvedCode else { throw ParseError.missingKey }
    return Shortcut(keyCode: code, flags: flags)
  }

  /// Whether the process may post keyboard events. With `prompt` macOS shows its
  /// Accessibility permission dialog when the permission is missing.
  static func isTrusted(prompt: Bool) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
    return AXIsProcessTrustedWithOptions(options as CFDictionary)
  }

  static func press(_ shortcut: Shortcut) {
    let source = CGEventSource(stateID: .combinedSessionState)
    guard
      let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false)
    else { return }
    down.flags = shortcut.flags
    up.flags = shortcut.flags
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }

  /// Types `text` as Unicode input, so any characters work regardless of keyboard layout.
  static func type(_ text: String) {
    let source = CGEventSource(stateID: .combinedSessionState)
    for chunk in chunks(of: text, size: 20) {
      var units = Array(chunk.utf16)
      guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
      else { return }
      down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
      up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
      down.post(tap: .cghidEventTap)
      up.post(tap: .cghidEventTap)
    }
  }

  static func chunks(of text: String, size: Int) -> [String] {
    var result: [String] = []
    var current = ""
    for character in text {
      current.append(character)
      if current.count == size {
        result.append(current)
        current = ""
      }
    }
    if !current.isEmpty { result.append(current) }
    return result
  }

  private static let modifiers: [String: CGEventFlags] = [
    "cmd": .maskCommand, "command": .maskCommand, "⌘": .maskCommand,
    "shift": .maskShift, "⇧": .maskShift,
    "alt": .maskAlternate, "opt": .maskAlternate, "option": .maskAlternate, "⌥": .maskAlternate,
    "ctrl": .maskControl, "control": .maskControl, "⌃": .maskControl,
    "fn": .maskSecondaryFn, "hyper": [.maskCommand, .maskShift, .maskAlternate, .maskControl],
    "✦": [.maskCommand, .maskShift, .maskAlternate, .maskControl],
  ]

  private static let namedKeys: [String: Int] = [
    "return": kVK_Return, "enter": kVK_Return, "↵": kVK_Return,
    "tab": kVK_Tab, "⇥": kVK_Tab,
    "space": kVK_Space, "␣": kVK_Space,
    "delete": kVK_Delete, "backspace": kVK_Delete, "⌫": kVK_Delete,
    "forwarddelete": kVK_ForwardDelete, "⌦": kVK_ForwardDelete,
    "escape": kVK_Escape, "esc": kVK_Escape, "⎋": kVK_Escape,
    "left": kVK_LeftArrow, "←": kVK_LeftArrow, "right": kVK_RightArrow, "→": kVK_RightArrow,
    "up": kVK_UpArrow, "↑": kVK_UpArrow, "down": kVK_DownArrow, "↓": kVK_DownArrow,
    "home": kVK_Home, "end": kVK_End, "pageup": kVK_PageUp, "pagedown": kVK_PageDown,
    "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6,
    "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
    "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket,
    "]": kVK_ANSI_RightBracket, ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
    ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash, "\\": kVK_ANSI_Backslash,
    "`": kVK_ANSI_Grave, "+": kVK_ANSI_Equal,
  ]

  private static func keyCode(for token: String) -> CGKeyCode? {
    if let entry = KeyMaps.byText[token.lowercased()] ?? KeyMaps.byGlyph[token.lowercased()],
      !entry.reserved || token.count > 1
    {
      return entry.code
    }
    if let entry = KeyMaps.byText[token] ?? KeyMaps.byGlyph[token] {
      return entry.code
    }
    if let code = namedKeys[token.lowercased()] {
      return CGKeyCode(code)
    }
    return nil
  }
}

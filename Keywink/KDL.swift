import Foundation

/// A small reader and writer for the KDL document language (https://kdl.dev), covering what a
/// configuration file needs: nodes with string, number, boolean, and null values, properties,
/// children, line and block comments, slashdash (`/-`) comments, raw and multi-line strings,
/// and line continuations. Type annotations such as `(u8)` are accepted and ignored.
enum KDL {
  enum Value: Equatable {
    case string(String)
    case number(String)
    case bool(Bool)
    case null

    /// The value as text; numbers keep their literal spelling, `#null` becomes nil.
    var stringValue: String? {
      switch self {
      case .string(let text), .number(let text): return text
      case .bool(let flag): return flag ? "true" : "false"
      case .null: return nil
      }
    }
  }

  struct Property: Equatable {
    let key: String
    let value: Value
  }

  struct Node: Equatable {
    var name: String
    var arguments: [Value] = []
    var properties: [Property] = []
    var children: [Node] = []

    /// KDL keeps the last occurrence of a repeated property.
    func property(_ key: String) -> Value? {
      properties.last { $0.key == key }?.value
    }
  }

  struct ParseError: LocalizedError, Equatable {
    let line: Int
    let message: String
    var errorDescription: String? { "Line \(line): \(message)" }
  }

  static func parse(_ text: String) throws -> [Node] {
    var parser = Parser(text)
    return try parser.parseDocument()
  }

  static func serialize(_ nodes: [Node]) -> String {
    var output = ""
    write(nodes, indent: 0, into: &output)
    return output
  }

  // MARK: - Writing

  private static func write(_ nodes: [Node], indent: Int, into output: inout String) {
    let pad = String(repeating: "    ", count: indent)
    for node in nodes {
      output += pad + identifier(node.name)
      for argument in node.arguments { output += " " + render(argument) }
      for property in node.properties {
        output += " " + identifier(property.key) + "=" + render(property.value)
      }
      if !node.children.isEmpty {
        output += " {\n"
        write(node.children, indent: indent + 1, into: &output)
        output += pad + "}"
      }
      output += "\n"
    }
  }

  private static func render(_ value: Value) -> String {
    switch value {
    case .string(let text): return quoted(text)
    case .number(let text): return text
    case .bool(let flag): return flag ? "#true" : "#false"
    case .null: return "#null"
    }
  }

  static func quoted(_ text: String) -> String {
    var result = "\""
    for character in text {
      switch character {
      case "\n": result += "\\n"
      case "\r": result += "\\r"
      case "\t": result += "\\t"
      case "\\": result += "\\\\"
      case "\"": result += "\\\""
      default: result.append(character)
      }
    }
    return result + "\""
  }

  private static let keywords: Set<String> = [
    "true", "false", "null", "inf", "-inf", "nan", "#true", "#false", "#null", "#inf", "#-inf",
    "#nan",
  ]

  /// Bare identifiers only for plain names; everything else is quoted.
  static func identifier(_ text: String) -> String {
    guard !text.isEmpty, !keywords.contains(text),
      text.allSatisfy({ !Parser.nonIdentifier.contains($0) && !$0.isWhitespace }),
      !Parser.looksNumeric(text)
    else { return quoted(text) }
    return text
  }

  // MARK: - Reading

  private struct Parser {
    static let nonIdentifier: Set<Character> = [
      "\\", "/", "(", ")", "{", "}", ";", "[", "]", "\"", "#", "=",
    ]

    static func looksNumeric(_ text: String) -> Bool {
      var scalars = Substring(text)
      if let first = scalars.first, first == "+" || first == "-" { scalars = scalars.dropFirst() }
      if scalars.first == "." { scalars = scalars.dropFirst() }
      return scalars.first?.isNumber ?? false
    }

    private let chars: [Character]
    private var index = 0
    private var line = 1

    init(_ text: String) {
      chars = Array(text)
    }

    private var current: Character? { index < chars.count ? chars[index] : nil }

    private func peek(_ offset: Int) -> Character? {
      index + offset < chars.count ? chars[index + offset] : nil
    }

    private func starts(_ prefix: String) -> Bool {
      var offset = 0
      for character in prefix {
        guard peek(offset) == character else { return false }
        offset += 1
      }
      return true
    }

    private mutating func advance() {
      if current == "\n" { line += 1 }
      index += 1
    }

    private func error(_ message: String) -> ParseError {
      ParseError(line: line, message: message)
    }

    mutating func parseDocument() throws -> [Node] {
      let nodes = try parseNodes()
      skipLineSpace()
      if let stray = current { throw error("Unexpected '\(stray)'") }
      return nodes
    }

    private mutating func parseNodes() throws -> [Node] {
      var nodes: [Node] = []
      while true {
        skipLineSpace()
        guard let character = current, character != "}" else { return nodes }
        if starts("/-") {
          advance()
          advance()
          skipLineSpace()
          _ = try parseNode()
          continue
        }
        nodes.append(try parseNode())
      }
    }

    private mutating func parseNode() throws -> Node {
      skipTypeAnnotation()
      guard let name = try parseIdentifierOrString() else {
        throw error("Expected a node name")
      }
      var node = Node(name: name)
      while true {
        try skipNodeSpace()
        guard let character = current else { return node }
        switch character {
        case "\n", "\r", ";":
          advance()
          return node
        case "}":
          return node
        case "/" where starts("//"):
          skipToLineEnd()
          return node
        case "{":
          node.children = try parseChildren()
          continue
        default:
          break
        }

        var slashdash = false
        if starts("/-") {
          advance()
          advance()
          slashdash = true
          try skipNodeSpace()
          if current == "{" {
            _ = try parseChildren()
            continue
          }
        }

        skipTypeAnnotation()
        let (value, propertyKey) = try parseValueOrProperty()
        if slashdash { continue }
        if let key = propertyKey {
          node.properties.append(Property(key: key, value: value))
        } else {
          node.arguments.append(value)
        }
      }
    }

    private mutating func parseChildren() throws -> [Node] {
      advance()  // {
      let children = try parseNodes()
      guard current == "}" else { throw error("Expected '}'") }
      advance()
      return children
    }

    /// Reads an argument or a `key=value` property.
    private mutating func parseValueOrProperty() throws -> (Value, String?) {
      if current == "\"" || (current == "#" && (peek(1) == "\"" || peek(1) == "#")) {
        let text = try parseString()
        if current == "=" {
          advance()
          skipTypeAnnotation()
          return (try parseValue(), text)
        }
        return (.string(text), nil)
      }

      let token = readBareToken()
      guard !token.isEmpty else {
        throw error("Unexpected '\(current.map(String.init) ?? "end of file")'")
      }
      if current == "=" {
        advance()
        skipTypeAnnotation()
        return (try parseValue(), token)
      }
      return (try interpret(token), nil)
    }

    private mutating func parseValue() throws -> Value {
      if current == "\"" || (current == "#" && (peek(1) == "\"" || peek(1) == "#")) {
        return .string(try parseString())
      }
      let token = readBareToken()
      guard !token.isEmpty else { throw error("Expected a value") }
      return try interpret(token)
    }

    private func interpret(_ token: String) throws -> Value {
      switch token {
      case "#true": return .bool(true)
      case "#false": return .bool(false)
      case "#null": return .null
      case "#inf", "#-inf", "#nan": return .number(token)
      case "true", "false", "null", "inf", "-inf", "nan":
        throw error("Use #\(token) for the keyword, or quote the string \"\(token)\"")
      default:
        if token.hasPrefix("#") { throw error("Unknown keyword '\(token)'") }
        return Parser.looksNumeric(token) ? .number(token) : .string(token)
      }
    }

    private mutating func parseIdentifierOrString() throws -> String? {
      if current == "\"" || (current == "#" && (peek(1) == "\"" || peek(1) == "#")) {
        return try parseString()
      }
      let token = readBareToken()
      guard !token.isEmpty else { return nil }
      if Parser.looksNumeric(token) || token.hasPrefix("#") {
        throw error("'\(token)' cannot be a node name; quote it")
      }
      return token
    }

    private mutating func readBareToken() -> String {
      var token = ""
      while let character = current, !character.isWhitespace, !character.isNewline,
        !Parser.nonIdentifier.contains(character) || (token.isEmpty && character == "#")
      {
        token.append(character)
        advance()
      }
      return token
    }

    // MARK: Strings

    private mutating func parseString() throws -> String {
      var hashes = 0
      while current == "#" {
        hashes += 1
        advance()
      }
      guard current == "\"" else { throw error("Expected '\"'") }
      advance()
      let raw = hashes > 0

      var text = ""
      let startLine = line
      while true {
        guard let character = current else {
          throw ParseError(line: startLine, message: "Unterminated string")
        }
        if character == "\"" {
          var trailing = 0
          while trailing < hashes, peek(trailing + 1) == "#" { trailing += 1 }
          if trailing == hashes {
            advance()
            for _ in 0..<hashes { advance() }
            break
          }
          text.append(character)
          advance()
          continue
        }
        if !raw, character == "\\" {
          try appendEscape(into: &text)
          continue
        }
        text.append(character)
        advance()
      }
      if text.first?.isNewline == true {
        return try dedent(text, line: startLine)
      }
      return text
    }

    private mutating func appendEscape(into text: inout String) throws {
      advance()  // backslash
      guard let escaped = current else { throw error("Unterminated escape") }
      switch escaped {
      case "n": text.append("\n")
      case "r": text.append("\r")
      case "t": text.append("\t")
      case "\\": text.append("\\")
      case "\"": text.append("\"")
      case "b": text.append("\u{08}")
      case "f": text.append("\u{0C}")
      case "s": text.append(" ")
      case "u":
        advance()
        guard current == "{" else { throw error("Expected '{' after \\u") }
        advance()
        var hex = ""
        while let digit = current, digit != "}" {
          hex.append(digit)
          advance()
        }
        guard let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) else {
          throw error("Invalid unicode escape \\u{\(hex)}")
        }
        text.unicodeScalars.append(scalar)
      default:
        if escaped.isWhitespace || escaped.isNewline {
          while let space = current, space.isWhitespace || space.isNewline { advance() }
          return
        }
        throw error("Unknown escape \\\(escaped)")
      }
      advance()
    }

    /// Multi-line strings drop the first line break and the closing line's indentation.
    private func dedent(_ text: String, line: Int) throws -> String {
      var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
      lines.removeFirst()
      guard let closing = lines.popLast(), closing.allSatisfy(\.isWhitespace) else {
        throw ParseError(
          line: line, message: "A multi-line string must end with a newline and indentation")
      }
      return try lines.map { content -> String in
        if content.allSatisfy(\.isWhitespace) { return "" }
        guard content.hasPrefix(closing) else {
          throw ParseError(line: line, message: "Multi-line string lines must share indentation")
        }
        return String(content.dropFirst(closing.count))
      }.joined(separator: "\n")
    }

    // MARK: Whitespace and comments

    /// Whitespace, newlines, and comments between nodes.
    private mutating func skipLineSpace() {
      while let character = current {
        if character.isWhitespace || character.isNewline || character == ";" {
          advance()
        } else if starts("//") {
          skipToLineEnd()
        } else if starts("/*") {
          skipBlockComment()
        } else {
          return
        }
      }
    }

    /// Whitespace inside a node, including `\` line continuations and block comments.
    private mutating func skipNodeSpace() throws {
      while let character = current {
        if character == "\n" || character == "\r" {
          return
        } else if character.isWhitespace {
          advance()
        } else if starts("/*") {
          skipBlockComment()
        } else if character == "\\" {
          advance()
          while let space = current, space.isWhitespace, !space.isNewline { advance() }
          if starts("//") { skipToLineEnd() }
          guard current == nil || current == "\n" || current == "\r" else {
            throw error("Expected a line break after '\\'")
          }
          if current != nil { advance() }
        } else {
          return
        }
      }
    }

    private mutating func skipToLineEnd() {
      while let character = current, character != "\n", character != "\r" { advance() }
    }

    private mutating func skipBlockComment() {
      var depth = 0
      while current != nil {
        if starts("/*") {
          depth += 1
          advance()
          advance()
        } else if starts("*/") {
          depth -= 1
          advance()
          advance()
          if depth == 0 { return }
        } else {
          advance()
        }
      }
    }

    private mutating func skipTypeAnnotation() {
      guard current == "(" else { return }
      while let character = current, character != ")" { advance() }
      if current == ")" { advance() }
    }
  }
}

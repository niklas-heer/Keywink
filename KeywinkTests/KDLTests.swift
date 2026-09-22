import XCTest

@testable import Keywink

final class KDLTests: XCTestCase {
  func testParsesNodesArgumentsPropertiesAndChildren() throws {
    let nodes = try KDL.parse(
      """
      // Comment
      group "o" label="Open" { /* block */
          application "s" "/Applications/Safari.app"
          url g "https://example.com" label="Example"; command t "echo hi"
      }
      text "e" "a@b.c" icon="mail.png"
      """)
    XCTAssertEqual(nodes.count, 2)
    XCTAssertEqual(nodes[0].name, "group")
    XCTAssertEqual(nodes[0].arguments, [.string("o")])
    XCTAssertEqual(nodes[0].property("label"), .string("Open"))
    XCTAssertEqual(nodes[0].children.map(\.name), ["application", "url", "command"])
    XCTAssertEqual(nodes[0].children[1].arguments, [.string("g"), .string("https://example.com")])
    XCTAssertEqual(nodes[0].children[1].property("label"), .string("Example"))
    XCTAssertEqual(nodes[1].property("icon"), .string("mail.png"))
  }

  func testParsesKeywordsNumbersSlashdashAndContinuations() throws {
    let nodes = try KDL.parse(
      """
      node 1 2.5 #true #null \\
           last=#false
      /-ignored "whole node"
      kept /-"skipped arg" "x" /-skipped=1 /-{ child }
      """)
    XCTAssertEqual(nodes.count, 2)
    XCTAssertEqual(nodes[0].arguments, [.number("1"), .number("2.5"), .bool(true), .null])
    XCTAssertEqual(nodes[0].property("last"), .bool(false))
    XCTAssertEqual(nodes[1].arguments, [.string("x")])
    XCTAssertTrue(nodes[1].properties.isEmpty)
    XCTAssertTrue(nodes[1].children.isEmpty)
  }

  func testParsesEscapesRawAndMultilineStrings() throws {
    let nodes = try KDL.parse(
      #"""
      a "tab\there\nnew \u{1F600} \"q\""
      b #"C:\raw\"quote"#
      c "
          first
            second
          "
      """#)
    XCTAssertEqual(nodes[0].arguments, [.string("tab\there\nnew 😀 \"q\"")])
    XCTAssertEqual(nodes[1].arguments, [.string(#"C:\raw\"quote"#)])
    XCTAssertEqual(nodes[2].arguments, [.string("first\n  second")])
  }

  func testReportsErrorsWithLineNumbers() {
    XCTAssertThrowsError(try KDL.parse("ok\nbad \"unterminated\n")) { error in
      XCTAssertEqual((error as? KDL.ParseError)?.line, 2)
    }
    XCTAssertThrowsError(try KDL.parse("group { child ")) { error in
      XCTAssertEqual((error as? KDL.ParseError)?.message, "Expected '}'")
    }
    XCTAssertThrowsError(try KDL.parse("node true"))
    XCTAssertThrowsError(try KDL.parse("1node"))
  }

  func testSerializesQuotedValuesAndRoundTrips() throws {
    let nodes = [
      KDL.Node(
        name: "group", arguments: [.string("1")],
        properties: [KDL.Property(key: "label", value: .string("Say \"hi\"\n"))],
        children: [
          KDL.Node(name: "command", arguments: [.string("t"), .string("echo $HOME")]),
          KDL.Node(name: "text", arguments: [.null, .string("")]),
        ])
    ]
    let text = KDL.serialize(nodes)
    XCTAssertEqual(
      text,
      """
      group "1" label="Say \\"hi\\"\\n" {
          command "t" "echo $HOME"
          text #null ""
      }

      """)
    XCTAssertEqual(try KDL.parse(text), nodes)
  }

  func testConfigRoundTripsThroughKDL() throws {
    let root = Group(
      key: nil,
      actions: [
        .group(
          Group(
            key: "o", label: "Open", iconPath: "folder",
            actions: [
              .action(Action(key: "s", type: .application, value: "/Applications/Safari.app")),
              .action(
                Action(key: "space", type: .url, label: "Search", value: "https://example.com")),
            ])),
        .action(Action(key: "e", type: .text, value: "hello@example.com", iconPath: "~/mail.png")),
        .action(Action(key: "4", type: .shortcut, value: "cmd+shift+4")),
      ])
    let text = KDLConfig.encode(root)
    XCTAssertTrue(text.hasPrefix("// Keywink configuration in KDL"), text)
    XCTAssertTrue(text.contains("group \"o\" label=\"Open\" icon=\"folder\" {"), text)
    XCTAssertTrue(text.contains("    url \"space\" \"https://example.com\" label=\"Search\""), text)
    XCTAssertTrue(text.contains("shortcut \"4\" \"cmd+shift+4\""), text)

    let decoded = try KDLConfig.decode(text)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    XCTAssertEqual(try encoder.encode(decoded), try encoder.encode(root))
  }

  func testConfigDecodeRejectsUnknownNodesAndMissingTargets() {
    XCTAssertThrowsError(try KDLConfig.decode("launch \"a\" \"/x\"")) { error in
      XCTAssertEqual(error as? KDLConfig.DecodeError, .unknownType("launch"))
    }
    XCTAssertThrowsError(try KDLConfig.decode("url \"a\"")) { error in
      XCTAssertEqual(error as? KDLConfig.DecodeError, .missingValue(type: "url", key: "a"))
    }
  }

  func testConfigDecodeAcceptsBareKeysAndComments() throws {
    let root = try KDLConfig.decode(
      """
      // Hand-written
      group o label=Open {
          application s "/Applications/Safari.app" // inline
          /-url old "https://gone.example"
      }
      """)
    XCTAssertEqual(root.actions.count, 1)
    guard case .group(let group) = root.actions[0] else { return XCTFail("expected a group") }
    XCTAssertEqual(group.key, "o")
    XCTAssertEqual(group.label, "Open")
    XCTAssertEqual(group.actions.count, 1)
  }
}

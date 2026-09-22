import SwiftUI
import XCTest

@testable import Keywink

/// Renders every Settings pane to a PNG so changes can be reviewed without a display or
/// screen-recording permission. Opt in with `KEYWINK_SNAPSHOT_DIR` (`mise run snapshots`);
/// without it the test is skipped. AppKit-backed controls such as the config editor and the
/// shortcut recorders render as empty placeholders, which is expected.
final class SettingsPaneSnapshotTests: XCTestCase {
  private static let environmentKey = "KEYWINK_SNAPSHOT_DIR"

  @MainActor
  func testRendersEverySettingsPane() throws {
    guard let directory = ProcessInfo.processInfo.environment[Self.environmentKey] else {
      throw XCTSkip("set \(Self.environmentKey) to write pane snapshots")
    }
    let outputURL = URL(fileURLWithPath: directory, isDirectory: true)
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let config = UserConfig(alertHandler: TestAlertManager())
    let panes: [(name: String, view: AnyView)] = [
      ("general", AnyView(GeneralPane().environmentObject(config))),
      ("advanced", AnyView(AdvancedPane().environmentObject(config))),
      ("statistics", AnyView(StatisticsPane())),
    ]

    for pane in panes {
      let renderer = ImageRenderer(
        content: pane.view
          .frame(width: 780)
          .background(Color(nsColor: .windowBackgroundColor)))
      renderer.scale = 2
      let image = try XCTUnwrap(renderer.nsImage, "\(pane.name) pane did not render")
      let tiff = try XCTUnwrap(image.tiffRepresentation)
      let png = try XCTUnwrap(
        NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
      let fileURL = outputURL.appendingPathComponent("pane-\(pane.name).png")
      try png.write(to: fileURL)
      XCTAssertGreaterThan(image.size.height, 100, "\(pane.name) pane rendered too small")
    }
  }
}

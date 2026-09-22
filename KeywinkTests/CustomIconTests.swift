import AppKit
import XCTest

@testable import Keywink

final class CustomIconTests: XCTestCase {
  func testRecognizesImageFilesButNotSymbolsOrApps() {
    XCTAssertTrue(CustomIcon.isImagePath("/Users/me/icons/todo.PNG"))
    XCTAssertTrue(CustomIcon.isImagePath("~/icons/mail.icns"))
    XCTAssertFalse(CustomIcon.isImagePath("/Applications/Safari.app"))
    XCTAssertFalse(CustomIcon.isImagePath("photo.fill"))
    XCTAssertFalse(CustomIcon.isImagePath(""))
  }

  func testLoadsAndScalesAnImageFile() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      "\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: file) }
    let source = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
      NSColor.systemPurple.setFill()
      rect.fill()
      return true
    }
    let tiff = try XCTUnwrap(source.tiffRepresentation)
    let png = try XCTUnwrap(
      NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
    try png.write(to: file)

    let icon = try XCTUnwrap(
      CustomIcon.image(atPath: file.path, size: NSSize(width: 24, height: 24)))
    XCTAssertEqual(icon.size, NSSize(width: 24, height: 24))
    XCTAssertNotNil(resolvedCustomIcon(file.path))
    XCTAssertNil(
      CustomIcon.image(atPath: "/nonexistent/icon.png", size: NSSize(width: 24, height: 24)))
  }
}

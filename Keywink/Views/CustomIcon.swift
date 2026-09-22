import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Image files used as icons for actions and groups, next to app bundles and SF Symbols.
/// An `iconPath` is treated as an image when its extension is a supported image format.
enum CustomIcon {
  static let contentTypes: [UTType] = [.png, .jpeg, .icns, .gif, .tiff, .heic, .bmp]

  private static let imageExtensions: Set<String> = [
    "png", "jpg", "jpeg", "icns", "gif", "tiff", "tif", "heic", "bmp",
  ]

  static func isImagePath(_ path: String) -> Bool {
    imageExtensions.contains((path as NSString).pathExtension.lowercased())
  }

  /// Loads the image, scaled to fit `size` with the rounded corners of an app icon.
  /// Returns nil when the file is missing or not an image.
  static func image(atPath path: String, size: NSSize) -> NSImage? {
    let expanded = (path as NSString).expandingTildeInPath
    guard let source = NSImage(contentsOfFile: expanded), source.isValid else { return nil }
    let image = NSImage(size: size, flipped: false) { rect in
      let radius = min(rect.width, rect.height) * 0.2
      NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
      source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
      return true
    }
    return image
  }
}

struct CustomIconImage: View {
  let imagePath: String
  let size: NSSize

  var body: some View {
    if let image = CustomIcon.image(atPath: imagePath, size: size) {
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size.width, height: size.height)
    } else {
      Image(systemName: "photo")
        .foregroundStyle(.secondary)
        .frame(width: size.width, height: size.height, alignment: .center)
    }
  }
}

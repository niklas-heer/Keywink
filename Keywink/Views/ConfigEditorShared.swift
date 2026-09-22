import AppKit
import ObjectiveC

enum ConfigEditorUI {
  static func setButtonTitle(_ button: NSButton, text: String, placeholder: Bool) {
    let attr = NSMutableAttributedString(string: text)
    let color: NSColor = placeholder ? .secondaryLabelColor : .labelColor
    attr.addAttribute(
      .foregroundColor, value: color, range: NSRange(location: 0, length: attr.length))
    button.title = text
    button.attributedTitle = attr
  }

  static func presentMoreMenu(
    anchor: NSView?,
    onDuplicate: @escaping () -> Void,
    onDelete: @escaping () -> Void
  ) {
    guard let anchor else { return }
    let menu = NSMenu()
    menu.addItem(
      withTitle: "Duplicate",
      action: #selector(MenuHandler.duplicate),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Delete",
      action: #selector(MenuHandler.delete),
      keyEquivalent: ""
    )
    let handler = MenuHandler(onDuplicate: onDuplicate, onDelete: onDelete)
    for item in menu.items { item.target = handler }
    objc_setAssociatedObject(
      menu,
      &handlerAssociationKey,
      handler,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    let point = NSPoint(x: 0, y: anchor.bounds.height)
    menu.popUp(positioning: nil, at: point, in: anchor)
  }

  static func presentIconMenu(
    anchor: NSView?,
    onPickAppIcon: @escaping () -> Void,
    onPickSymbol: @escaping () -> Void,
    onPickImage: @escaping () -> Void,
    onClear: @escaping () -> Void
  ) {
    guard let anchor else { return }
    let menu = NSMenu()
    menu.addItem(
      withTitle: "App Icon…",
      action: #selector(MenuHandler.pickAppIcon),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Symbol…",
      action: #selector(MenuHandler.pickSymbol),
      keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Image File…",
      action: #selector(MenuHandler.pickImage),
      keyEquivalent: ""
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Clear", action: #selector(MenuHandler.clearIcon), keyEquivalent: "")
    let handler = MenuHandler(
      onPickAppIcon: onPickAppIcon,
      onPickSymbol: onPickSymbol,
      onPickImage: onPickImage,
      onClearIcon: onClear,
      onDuplicate: {},
      onDelete: {}
    )
    for item in menu.items { item.target = handler }
    objc_setAssociatedObject(
      menu,
      &handlerAssociationKey,
      handler,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    let point = NSPoint(x: 0, y: anchor.bounds.height)
    menu.popUp(positioning: nil, at: point, in: anchor)
  }

  private static var handlerAssociationKey: UInt8 = 0

  private final class MenuHandler: NSObject {
    let onPickAppIcon: (() -> Void)?
    let onPickSymbol: (() -> Void)?
    let onPickImage: (() -> Void)?
    let onClearIcon: (() -> Void)?
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    init(
      onPickAppIcon: (() -> Void)? = nil,
      onPickSymbol: (() -> Void)? = nil,
      onPickImage: (() -> Void)? = nil,
      onClearIcon: (() -> Void)? = nil,
      onDuplicate: @escaping () -> Void,
      onDelete: @escaping () -> Void
    ) {
      self.onPickAppIcon = onPickAppIcon
      self.onPickSymbol = onPickSymbol
      self.onPickImage = onPickImage
      self.onClearIcon = onClearIcon
      self.onDuplicate = onDuplicate
      self.onDelete = onDelete
    }

    @objc func pickAppIcon() { onPickAppIcon?() }
    @objc func pickSymbol() { onPickSymbol?() }
    @objc func pickImage() { onPickImage?() }
    @objc func clearIcon() { onClearIcon?() }
    @objc func duplicate() { onDuplicate() }
    @objc func delete() { onDelete() }
  }
}

/// Icon for an explicit `iconPath`: an app bundle, an image file, or an SF Symbol name.
func resolvedCustomIcon(_ iconPath: String?) -> NSImage? {
  guard let iconPath, !iconPath.isEmpty else { return nil }
  if iconPath.hasSuffix(".app") { return NSWorkspace.shared.icon(forFile: iconPath) }
  if CustomIcon.isImagePath(iconPath) {
    return CustomIcon.image(atPath: iconPath, size: NSSize(width: 28, height: 28))
  }
  return NSImage(systemSymbolName: iconPath, accessibilityDescription: nil)
}

extension Action {
  func resolvedIcon() -> NSImage? {
    if let icon = resolvedCustomIcon(iconPath) { return icon }
    switch type {
    case .application:
      return NSWorkspace.shared.icon(forFile: value)
    case .url:
      return NSImage(systemSymbolName: "link", accessibilityDescription: nil)
    case .command:
      return NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
    case .folder:
      return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
    case .text:
      return NSImage(systemSymbolName: "text.cursor", accessibilityDescription: nil)
    case .shortcut:
      return NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
    default:
      return NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil)
    }
  }
}

extension Group {
  func resolvedIcon() -> NSImage? {
    if let icon = resolvedCustomIcon(iconPath) { return icon }
    return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
  }
}

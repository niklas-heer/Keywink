import Cocoa
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI

/// A centered keyboard guide that presents shortcuts like editor completions.
enum TopEdge {
  struct Layout {
    let frame: NSRect

    static func make(
      screenFrame: NSRect, visibleFrame: NSRect, itemCount: Int
    ) -> Layout {
      let available = visibleFrame.intersection(screenFrame)
      let width = min(440, max(0, available.width - 40))
      let rows = max(1, min(10, itemCount))
      let height = min(
        max(0, available.height - 40),
        52 + CGFloat(rows) * 32 + CGFloat(rows - 1) * 2)
      return Layout(
        frame: NSRect(
          x: available.midX - width / 2,
          y: available.midY - height / 2,
          width: width,
          height: height))
    }
  }

  class Window: MainWindow {
    override var hasCheatsheet: Bool { false }
    private var selectedScreen: NSScreen?
    private var observation: AnyCancellable?
    private var screenObservation: AnyCancellable?
    private var presentation: UInt = 0
    private var dismissing = false

    required init(controller: Controller) {
      super.init(controller: controller, contentRect: .zero)
      hasShadow = true
      level = .floating
      collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      contentView = NSHostingView(
        rootView: MainView(
          choose: { [weak controller] key in controller?.handleKey(key) },
          goBack: { [weak controller] in controller?.goBack() }
        )
        .environmentObject(controller.usage)
        .environmentObject(controller.userState)
        .environmentObject(controller.userConfig))

      observation = Publishers.Merge(
        controller.userState.objectWillChange,
        controller.userConfig.objectWillChange
      )
      .receive(on: RunLoop.main)
      .sink { [weak self] in
        guard let self, self.isVisible, !self.dismissing else { return }
        self.position(animated: true)
      }

      screenObservation = NotificationCenter.default.publisher(
        for: NSApplication.didChangeScreenParametersNotification
      )
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let self, self.isVisible, !self.dismissing else { return }
        let screenID =
          self.selectedScreen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
          as? NSNumber
        self.selectedScreen =
          NSScreen.screens.first {
            $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber == screenID
          } ?? NSScreen.main
        self.position(animated: false)
      }
    }

    override func show(on screen: NSScreen, after: (() -> Void)? = nil) {
      if isVisible && !dismissing {
        selectedScreen = screen
        position(animated: true)
        after?()
        return
      }
      presentation &+= 1
      dismissing = false
      let current = presentation
      selectedScreen = screen
      position(animated: false)
      alphaValue = 0
      makeKeyAndOrderFront(nil)
      NSAnimationContext.runAnimationGroup { context in
        context.duration = reducedMotion ? 0 : 0.18
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animator().alphaValue = 1
      } completionHandler: { [weak self] in
        guard let self, self.presentation == current, !self.dismissing else { return }
        after?()
      }
    }

    override func hide(after: (() -> Void)? = nil) {
      guard !dismissing else { return }
      dismissing = true
      presentation &+= 1
      let current = presentation
      NSAnimationContext.runAnimationGroup { context in
        context.duration = reducedMotion ? 0 : 0.12
        animator().alphaValue = 0
      } completionHandler: { [weak self] in
        guard let self, self.presentation == current else { return }
        self.orderOut(nil)
        self.dismissing = false
        after?()
      }
    }

    override func windowDidResignKey(_ notification: Notification) {
      if !dismissing { controller.hide() }
    }

    override func notFound() {
      NSSound.beep()
    }

    private var reducedMotion: Bool {
      NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func position(animated: Bool) {
      guard let screen = selectedScreen else { return }
      let items = controller.userState.currentGroup?.actions ?? controller.userConfig.root.actions
      let layout = Layout.make(
        screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
        itemCount: controller.userState.isShowingRefreshState ? 0 : items.count)
      if animated && !reducedMotion {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.18
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          animator().setFrame(layout.frame, display: true)
        }
      } else {
        setFrame(layout.frame, display: true)
      }
    }
  }

  struct MainView: View {
    @EnvironmentObject private var usage: UsageStatistics
    @Default(.rankByFrequency) private var rankByFrequency
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var userConfig: UserConfig
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let choose: (String) -> Void
    let goBack: () -> Void

    private var items: [ActionOrGroup] {
      let configured = userState.currentGroup?.actions ?? userConfig.root.actions
      return rankByFrequency
        ? usage.ranked(configured, parentPath: userState.keyPath, appID: userState.sourceAppID)
        : configured
    }

    var body: some View {
      VStack(spacing: 4) {
        contextPath

        ScrollView {
          if userState.isShowingRefreshState {
            Label("Configuration reloaded", systemImage: "checkmark")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, minHeight: 32)
          } else if items.isEmpty {
            Text("Add shortcuts in Settings to get started.")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, minHeight: 32)
          } else {
            LazyVStack(spacing: 2) {
              ForEach(items, id: \.uiid) { item in
                Shortcut(item: item, globalShortcut: globalShortcut(for: item)) {
                  if let key = item.item.key { choose(key) }
                }
              }
            }
          }
        }
        .id(userState.navigationPath.map(\.uiid))
        .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(x: 8)))
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background {
        if reduceTransparency {
          Color(nsColor: .windowBackgroundColor)
        } else {
          VisualEffectView(material: .popover, blendingMode: .behindWindow)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
      .animation(
        reduceMotion ? nil : .easeOut(duration: 0.16), value: userState.navigationPath.map(\.uiid))
    }

    private func globalShortcut(for item: ActionOrGroup) -> KeyboardShortcuts.Shortcut? {
      guard userState.navigationPath.isEmpty, case .group(let group) = item,
        let key = group.key, Defaults[.groupShortcuts].contains(key)
      else { return nil }
      return GlobalShortcuts.shortcut(for: GlobalShortcuts.groupName(for: key))
    }

    private var sequenceHint: String {
      let path = userState.keyPath
      if let first = path.first, Defaults[.groupShortcuts].contains(first),
        let shortcut = GlobalShortcuts.shortcut(for: GlobalShortcuts.groupName(for: first))
      {
        return
          ([TopEdge.shortcutLabel(shortcut)] + path.dropFirst().map { KeyMaps.glyph(for: $0) ?? $0 })
          .joined(separator: " › ")
      }
      let root = GlobalShortcuts.shortcut(for: .activate).map(TopEdge.shortcutLabel)
      return ([root].compactMap { $0 } + path.map { KeyMaps.glyph(for: $0) ?? $0 })
        .joined(separator: " › ")
    }

    private var contextPath: some View {
      HStack(spacing: 8) {
        if !userState.navigationPath.isEmpty {
          Button(action: goBack) {
            Image(systemName: "chevron.backward")
              .font(.system(size: 10, weight: .semibold))
              .frame(width: 20, height: 24)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Go up one level")
          .help("Go up one level (Backspace)")
        }
        Text("$ keywink")
          .foregroundStyle(.secondary)
        if !userState.navigationPath.isEmpty {
          Text("/").foregroundStyle(.tertiary)
          Text(userState.navigationPath.map(\.displayName).joined(separator: " / "))
            .lineLimit(1)
            .truncationMode(.head)
        }
        Spacer(minLength: 8)
        if !sequenceHint.isEmpty {
          Text(sequenceHint)
            .lineLimit(1)
            .truncationMode(.head)
            .layoutPriority(1)
            .foregroundStyle(.secondary)
            .help("Shortcut to this group. ✦ = Hyper (Control–Option–Shift–Command). › means then.")
            .accessibilityLabel(sequenceHint.replacingOccurrences(of: "✦", with: "Hyper "))
        }
      }
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .padding(.horizontal, 7)
      .frame(height: 24)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(.primary.opacity(0.08))
          .frame(height: 1)
          .offset(y: 2)
      }
    }
  }

  @MainActor
  static func shortcutLabel(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
    let hyper: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    guard shortcut.modifiers.intersection(hyper) == hyper else { return shortcut.description }
    return "✦ " + shortcut.description.filter { !"⌃⌥⇧⌘".contains($0) }
  }

  private struct Shortcut: View {
    let item: ActionOrGroup
    let globalShortcut: KeyboardShortcuts.Shortcut?
    let choose: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var labelStartsWithEmoji: Bool {
      guard
        let first = item.item.displayName.trimmingCharacters(in: .whitespacesAndNewlines).first
      else { return false }
      return first.unicodeScalars.contains {
        $0.properties.isEmojiPresentation
          || $0.value == 0xFE0F
          || ($0.properties.isEmoji && $0.value >= 0x1F000)
      }
    }

    var body: some View {
      Button(action: choose) {
        HStack(spacing: 9) {
          Text(KeyMaps.glyph(for: item.item.key ?? "") ?? item.item.key ?? "—")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(minWidth: 22, minHeight: 20)
            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
          if !labelStartsWithEmoji {
            actionIcon(item: item, iconSize: NSSize(width: 17, height: 17), loadFavicons: false)
              .accessibilityHidden(true)
          }
          Text(item.item.displayName)
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: 8)
          if let globalShortcut {
            Text(TopEdge.shortcutLabel(globalShortcut))
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(.secondary)
              .help("Global shortcut. ✦ = Hyper (Control–Option–Shift–Command).")
          }
          if case .group = item {
            Image(systemName: "chevron.forward")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.horizontal, 7)
        .frame(height: 32)
        .background(
          .primary.opacity(hovered ? 0.065 : 0), in: RoundedRectangle(cornerRadius: 5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 5))
      }
      .buttonStyle(.plain)
      .onHover { hovered = $0 }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: hovered)
      .accessibilityLabel("\(item.item.key ?? ""): \(item.item.displayName)")
      .accessibilityHint(item.item.type == .group ? "Open shortcut group" : "Run shortcut")
    }
  }
}

import Cocoa
import Combine
import SwiftUI

/// A centered keyboard guide that presents shortcuts like editor completions.
enum TopEdge {
  struct Layout {
    let frame: NSRect
    let columns: Int

    static func make(
      screenFrame: NSRect, visibleFrame: NSRect, itemCount: Int,
      hasBreadcrumb: Bool = false
    ) -> Layout {
      let available = visibleFrame.intersection(screenFrame)
      let width = min(560, max(0, available.width - 40))
      let columns = width >= 440 ? 2 : 1
      let rows = max(1, min(6, Int(ceil(Double(itemCount) / Double(columns)))))
      let height = min(
        max(0, available.height - 40),
        24 + CGFloat(rows) * 40 + CGFloat(rows - 1) * 4 + (hasBreadcrumb ? 32 : 0))
      return Layout(
        frame: NSRect(
          x: available.midX - width / 2,
          y: available.midY - height / 2,
          width: width,
          height: height),
        columns: columns)
    }
  }

  class Window: MainWindow {
    override var hasCheatsheet: Bool { false }
    private var selectedScreen: NSScreen?
    private var observation: AnyCancellable?
    private var screenObservation: AnyCancellable?
    private var presentation: UInt = 0
    private var dismissing = false
    private let model = Presentation()

    required init(controller: Controller) {
      super.init(controller: controller, contentRect: .zero)
      hasShadow = true
      level = .floating
      collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      contentView = NSHostingView(
        rootView: MainView(
          presentation: model,
          choose: { [weak controller] key in controller?.handleKey(key) },
          reset: { [weak controller] in controller?.userState.clear() }
        )
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
        itemCount: controller.userState.isShowingRefreshState ? 0 : items.count,
        hasBreadcrumb: !controller.userState.navigationPath.isEmpty
          && !controller.userState.isShowingRefreshState)
      model.columns = layout.columns
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

  final class Presentation: ObservableObject {
    @Published var columns = 2
  }

  struct MainView: View {
    @ObservedObject var presentation: Presentation
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var userConfig: UserConfig
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let choose: (String) -> Void
    let reset: () -> Void

    private var items: [ActionOrGroup] {
      userState.currentGroup?.actions ?? userConfig.root.actions
    }

    var body: some View {
      VStack(spacing: 8) {
        if !userState.navigationPath.isEmpty && !userState.isShowingRefreshState {
          contextPath
        }

        ScrollView {
          if userState.isShowingRefreshState {
            Label("Configuration reloaded", systemImage: "checkmark")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, minHeight: 37)
          } else if items.isEmpty {
            Text("Add shortcuts in Settings to get started.")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, minHeight: 37)
          } else {
            LazyVGrid(
              columns: Array(
                repeating: GridItem(.flexible(), spacing: 22), count: presentation.columns),
              spacing: 4
            ) {
              ForEach(items, id: \.uiid) { item in
                Shortcut(item: item) {
                  if let key = item.item.key { choose(key) }
                }
              }
            }
          }
        }
        .id(userState.navigationPath.map(\.uiid))
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
        reduceMotion ? nil : .easeInOut(duration: 0.18), value: userState.navigationPath.count)
    }

    private var contextPath: some View {
      Button(action: reset) {
        HStack(spacing: 7) {
          Image(systemName: "chevron.backward")
            .font(.system(size: 9, weight: .semibold))
          Text("$ keywink")
            .foregroundStyle(.tertiary)
          Text("/")
            .foregroundStyle(.tertiary)
          Text(userState.navigationPath.map(\.displayName).joined(separator: " / "))
            .lineLimit(1)
            .truncationMode(.head)
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .font(.system(size: 11, weight: .medium, design: .monospaced))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 7)
      .frame(height: 24)
      .accessibilityLabel(
        "All shortcuts, \(userState.navigationPath.map(\.displayName).joined(separator: ", "))"
      )
      .accessibilityHint("Return to the root shortcuts. You can also press Backspace.")
    }
  }

  private struct Shortcut: View {
    let item: ActionOrGroup
    let choose: () -> Void
    @State private var hovered = false

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
            .foregroundStyle(.secondary)
            .frame(width: 25, height: 24)
            .background(.primary.opacity(0.075), in: RoundedRectangle(cornerRadius: 6))
          if !labelStartsWithEmoji {
            actionIcon(item: item, iconSize: NSSize(width: 17, height: 17), loadFavicons: false)
              .accessibilityHidden(true)
          }
          Text(item.item.displayName)
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: 0)
          if case .group = item {
            Image(systemName: "chevron.forward")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.horizontal, 7)
        .frame(height: 40)
        .background(
          .primary.opacity(hovered ? 0.065 : 0), in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .onHover { hovered = $0 }
      .accessibilityLabel("\(item.item.key ?? ""): \(item.item.displayName)")
      .accessibilityHint(item.item.type == .group ? "Open shortcut group" : "Run shortcut")
    }
  }
}

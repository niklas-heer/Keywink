import Cocoa
import Combine
import SwiftUI

/// A top-anchored launcher that keeps all interactive content below the camera housing.
enum TopEdge {
  struct Layout {
    let frame: NSRect
    let columns: Int

    static func make(
      screenFrame: NSRect, visibleFrame: NSRect, safeTop: CGFloat,
      itemCount: Int, hasBreadcrumb: Bool = false
    ) -> Layout {
      let available = visibleFrame.intersection(screenFrame)
      let width = min(536, max(0, available.width - 32))
      let columns = width >= 380 ? 2 : 1
      let rows = max(1, min(6, Int(ceil(Double(itemCount) / Double(columns)))))
      let height = min(
        max(0, available.height - 32),
        28 + CGFloat(rows) * 37 + CGFloat(rows - 1) * 3 + (hasBreadcrumb ? 32 : 0))
      let top = min(screenFrame.maxY - safeTop, available.maxY) - 16
      let centeredX = screenFrame.midX - width / 2
      let x = min(max(centeredX, available.minX + 16), available.maxX - width - 16)
      return Layout(
        frame: NSRect(x: x, y: top - height, width: width, height: height),
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
        safeTop: screen.safeAreaInsets.top,
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
          breadcrumb
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
              spacing: 3
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
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background {
        if reduceTransparency {
          Color(nsColor: .windowBackgroundColor)
        } else {
          VisualEffectView(material: .popover, blendingMode: .behindWindow)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.18), value: userState.navigationPath.count)
    }

    private var breadcrumb: some View {
      HStack(spacing: 8) {
        Button(action: reset) {
          Label("All shortcuts", systemImage: "arrow.left")
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityHint("Return to the root shortcuts. You can also press Backspace.")
        Text("/")
        Text(userState.navigationPath.map(\.displayName).joined(separator: " / "))
          .lineLimit(1)
          .truncationMode(.head)
        Spacer(minLength: 0)
      }
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .frame(height: 24)
    }
  }

  private struct Shortcut: View {
    let item: ActionOrGroup
    let choose: () -> Void
    @State private var hovered = false

    var body: some View {
      Button(action: choose) {
        HStack(spacing: 11) {
          Text(KeyMaps.glyph(for: item.item.key ?? "") ?? item.item.key ?? "—")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .frame(width: 24, height: 24)
            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
          Text(item.item.displayName)
            .font(.system(size: 13))
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: 0)
          if case .group = item {
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal, 8)
        .frame(height: 37)
        .background(
          .primary.opacity(hovered ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 7)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
      }
      .buttonStyle(.plain)
      .onHover { hovered = $0 }
      .accessibilityLabel("\(item.item.key ?? ""): \(item.item.displayName)")
      .accessibilityHint(item.item.type == .group ? "Open shortcut group" : "Run shortcut")
    }
  }
}

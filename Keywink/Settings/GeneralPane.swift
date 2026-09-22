import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import Settings
import SwiftUI
import UniformTypeIdentifiers

struct GeneralPane: View {
  private let contentWidth = 720.0
  @EnvironmentObject private var config: UserConfig
  @Default(.configDir) var configDir
  @Default(.theme) var theme

  var body: some View {
    Settings.Container(contentWidth: contentWidth) {
      Settings.Section(
        title: "Config", bottomDivider: true, verticalAlignment: .top
      ) {
        VStack(alignment: .leading, spacing: 8) {
          // AppKit-backed editor for maximum smoothness
          ConfigOutlineEditorView(root: $config.root)
            .frame(height: 500)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .inset(by: 1)
                .stroke(Color.primary, lineWidth: 1)
                .opacity(0.1)
            )

          if !config.validationErrors.isEmpty {
            ValidationWarningView(errors: config.validationErrors)
              .transition(.opacity)
          }

          HStack {
            // Left-aligned buttons
            HStack(spacing: 8) {
              Button(action: {
                config.root.actions.append(.action(Action(key: "", type: .application, value: "")))
              }) {
                Image(systemName: "rays")
                Text("Add Action")
              }

              Button(action: {
                config.root.actions.append(.group(Group(key: "", actions: [])))
              }) {
                Image(systemName: "folder")
                Text("Add Group")
              }

              Divider()
                .frame(height: 20)

              Button("Read from file") {
                config.reloadFromFile()
              }
            }

            Spacer()

            // Right-aligned buttons
            HStack(spacing: 8) {
              Button(action: {
                NotificationCenter.default.post(name: .lkExpandAll, object: nil)
              }) {
                Image(systemName: "chevron.down")
                Text("All")
              }

              Button(action: {
                NotificationCenter.default.post(name: .lkCollapseAll, object: nil)
              }) {
                Image(systemName: "chevron.right")
                Text("All")
              }

              Button(action: {
                NotificationCenter.default.post(name: .lkSortAZ, object: nil)
              }) {
                Image(systemName: "arrow.up.arrow.down")
                Text("Sort")
              }
            }
          }
        }
      }

      Settings.Section(title: "Shortcuts", verticalAlignment: .top) {
        Grid(alignment: .leading, verticalSpacing: 8) {
          GridRow {
            Text("Activate")
            KeyboardShortcuts.Recorder(
              shortcut: Binding(
                get: { GlobalShortcuts.shortcut(for: .activate) },
                set: { GlobalShortcuts.set($0, for: .activate) }))
          }
          GridRow {
            Text("Repeat last action")
            KeyboardShortcuts.Recorder(
              shortcut: Binding(
                get: { GlobalShortcuts.shortcut(for: .repeatLastAction) },
                set: { GlobalShortcuts.set($0, for: .repeatLastAction) }))
          }
        }
      }

      Settings.Section(title: "Theme") {
        Picker("Theme", selection: $theme) {
          ForEach(Theme.all, id: \.self) { value in
            Text(Theme.name(value)).tag(value)
          }
        }.frame(maxWidth: 170).labelsHidden()
      }

      Settings.Section(title: "App", bottomDivider: true) {
        LaunchAtLogin.Toggle()
      }

      Settings.Section(title: "Import", verticalAlignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Button("Import Leader Key config…", action: importLeaderKeyConfig)
          Text(
            "Validates a Leader Key config.json and copies it into Keywink. Your current configuration is backed up first."
          )
          .font(.caption)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  private func importLeaderKeyConfig() {
    let panel = NSOpenPanel()
    panel.title = "Import Leader Key configuration"
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.directoryURL = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first?.appendingPathComponent("Leader Key", isDirectory: true)
    guard panel.runModal() == .OK, let source = panel.url else { return }

    let confirmation = NSAlert()
    confirmation.messageText = "Replace Keywink's configuration?"
    confirmation.informativeText =
      "The selected configuration will be copied to Keywink. Your current configuration will be backed up beside config.json. The original file will remain unchanged. Shortcuts and app preferences are not imported."
    confirmation.addButton(withTitle: "Import")
    confirmation.addButton(withTitle: "Cancel")
    guard confirmation.runModal() == .alertFirstButtonReturn else { return }

    do {
      let backupURL = try config.importConfig(from: source)
      let result = NSAlert()
      result.messageText = "Configuration imported"
      result.informativeText =
        backupURL.map { "Previous configuration saved at \($0.path)." }
        ?? "Keywink is ready to use the imported configuration."
      result.runModal()
    } catch {
      NSAlert(error: error).runModal()
    }
  }
}

struct GeneralPane_Previews: PreviewProvider {
  static var previews: some View {
    return GeneralPane()
      .environmentObject(UserConfig())
  }
}

/// Compact banner that surfaces validation issues directly in the settings UI.
private struct ValidationWarningView: View {
  private let errors: [ValidationError]
  private let maxVisibleErrors = 3

  init(errors: [ValidationError]) {
    self.errors = errors
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(warningTitle)
        .font(.callout)
        .fontWeight(.semibold)

      VStack(alignment: .leading, spacing: 2) {
        ForEach(Array(errors.prefix(maxVisibleErrors))) { error in
          Text("• \(error.message)")
            .font(.caption)
        }

        if errors.count > maxVisibleErrors {
          Text("• …and \(errors.count - maxVisibleErrors) more issues")
            .font(.caption)
        }

        Text(
          "Configuration saves continue, but shortcuts tied to these keys may misbehave until fixed."
        )
        .font(.caption)
        .padding(.top, 4)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .textBackgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.red.opacity(0.6), lineWidth: 1)
    )
    .cornerRadius(8)
    .foregroundColor(.red)
  }

  private var warningTitle: String {
    let count = errors.count
    let issueText = count == 1 ? "1 issue" : "\(count) issues"
    let pronoun = count == 1 ? "it" : "they"
    return "Configuration has \(issueText). Some shortcuts may not work until \(pronoun) are fixed."
  }
}

import Defaults
import Settings
import SwiftUI

struct StatisticsPane: View {
  @ObservedObject private var statistics = UsageStatistics.shared
  @State private var showingResetConfirmation = false

  var body: some View {
    Settings.Container(contentWidth: 640) {
      Settings.Section(title: "Usage", bottomDivider: true) {
        Defaults.Toggle("Track usage", key: .trackUsage)
        Text("Counts stay on this Mac. Turning tracking off keeps your existing statistics.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(width: 500, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)

        Defaults.Toggle("Rank via frequency", key: .rankByFrequency)
          .padding(.top, 8)
        Text(
          "Show frequently viewed groups and frequently chosen actions first for the current application. Groups without history in that application use your overall counts. Shortcut keys stay the same."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 500, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
      }

      Settings.Section(title: "Totals", bottomDivider: true) {
        HStack(spacing: 28) {
          metric("Opens", value: statistics.totalOpenings)
          metric("Group views", value: statistics.groupViews)
          metric("Actions chosen", value: statistics.actionUses)
        }
        .padding(.vertical, 4)
      }

      Settings.Section(title: "By application", bottomDivider: true) {
        VStack(alignment: .leading, spacing: 8) {
          Text("The application you were using when Keywink opened.")
            .font(.caption)
            .foregroundStyle(.secondary)

          if statistics.applications.isEmpty {
            Text("Open Keywink to start building your statistics.")
              .foregroundStyle(.secondary)
              .padding(.vertical, 16)
          } else {
            HStack(spacing: 12) {
              Text("Application")
                .frame(maxWidth: .infinity, alignment: .leading)
              Text("Opens").frame(width: 52, alignment: .trailing)
              Text("Views").frame(width: 52, alignment: .trailing)
              Text("Actions").frame(width: 52, alignment: .trailing)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ScrollView {
              LazyVStack(spacing: 0) {
                ForEach(statistics.applications) { application in
                  HStack(spacing: 12) {
                    Text(application.name)
                      .lineLimit(1)
                      .truncationMode(.tail)
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .help(application.appID)
                    count(application.openings)
                    count(application.groupViews)
                    count(application.actionUses)
                  }
                  .padding(.vertical, 6)
                }
              }
            }
            .frame(height: min(CGFloat(statistics.applications.count) * 30, 210))
          }
        }
      }

      Settings.Section(title: "History") {
        Button("Reset statistics…") {
          showingResetConfirmation = true
        }
        .disabled(
          statistics.totalOpenings == 0 && statistics.groupViews == 0
            && statistics.actionUses == 0)
      }
    }
    .alert("Reset usage statistics?", isPresented: $showingResetConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) {
        statistics.reset()
      }
    } message: {
      Text("This clears all usage counts and starts frequency ranking over.")
    }
  }

  private func metric(_ title: String, value: Int) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value.formatted())
        .font(.title2.monospacedDigit())
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func count(_ value: Int) -> some View {
    Text(value.formatted())
      .monospacedDigit()
      .frame(width: 52, alignment: .trailing)
  }
}

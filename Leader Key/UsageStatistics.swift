import Combine
import Foundation

final class UsageStatistics: ObservableObject {
  static let shared = UsageStatistics(defaults: defaultsSuite)
  static let storageKey = "usageStatistics"

  struct ApplicationSummary: Identifiable, Equatable {
    var id: String { appID }
    let appID: String
    let name: String
    let openings: Int
    let groupViews: Int
    let actionUses: Int
  }

  @Published private(set) var totalOpenings = 0
  @Published private(set) var groupViews = 0
  @Published private(set) var actionUses = 0
  @Published private(set) var applications: [ApplicationSummary] = []

  private struct ApplicationRecord: Codable {
    var name: String
    var openings = 0
    var groups: [String: Int] = [:]
    var actions: [String: Int] = [:]
  }

  private struct StoredStatistics: Codable {
    var version = 1
    var applications: [String: ApplicationRecord] = [:]
  }

  private let defaults: UserDefaults
  private var statistics = StoredStatistics()

  init(defaults: UserDefaults = defaultsSuite) {
    self.defaults = defaults
    if let data = defaults.data(forKey: Self.storageKey),
      let stored = try? JSONDecoder().decode(StoredStatistics.self, from: data),
      stored.version == 1
    {
      statistics = stored
    }
    publish()
  }

  func recordOpening(appID: String, appName: String) {
    var record = statistics.applications[appID] ?? ApplicationRecord(name: appName)
    record.name = appName
    record.openings += 1
    statistics.applications[appID] = record
    save()
  }

  func recordGroup(path: [String], appID: String) {
    guard !path.isEmpty else { return }
    var record = statistics.applications[appID] ?? ApplicationRecord(name: appID)
    record.groups[pathKey(path), default: 0] += 1
    statistics.applications[appID] = record
    save()
  }

  func recordAction(path: [String], appID: String) {
    guard !path.isEmpty else { return }
    var record = statistics.applications[appID] ?? ApplicationRecord(name: appID)
    record.actions[pathKey(path), default: 0] += 1
    statistics.applications[appID] = record
    save()
  }

  func count(path: [String], appID: String? = nil) -> Int {
    let key = pathKey(path)
    if let appID {
      guard let record = statistics.applications[appID] else { return 0 }
      return (record.groups[key] ?? 0) + (record.actions[key] ?? 0)
    }
    return statistics.applications.values.reduce(0) {
      $0 + ($1.groups[key] ?? 0) + ($1.actions[key] ?? 0)
    }
  }

  func ranked(
    _ items: [ActionOrGroup], parentPath: [String], appID: String? = nil
  ) -> [ActionOrGroup] {
    func counts(in context: String?) -> [Int] {
      items.map { item in
        guard let key = item.item.key else { return 0 }
        return count(path: parentPath + [key], appID: context)
      }
    }
    var scores = counts(in: appID)
    // A new application starts with the user's overall ordering until it has its own history.
    if appID != nil && !scores.contains(where: { $0 > 0 }) {
      scores = counts(in: nil)
    }
    return items.enumerated().sorted { lhs, rhs in
      if scores[lhs.offset] == scores[rhs.offset] { return lhs.offset < rhs.offset }
      return scores[lhs.offset] > scores[rhs.offset]
    }.map(\.element)
  }

  func reset() {
    statistics = StoredStatistics()
    defaults.removeObject(forKey: Self.storageKey)
    publish()
  }

  private func pathKey(_ path: [String]) -> String {
    // JSON arrays distinguish nested keys even when a key contains a separator.
    let keys = path.map { KeyMaps.text(for: $0) ?? $0 }
    let data = try! JSONEncoder().encode(keys)
    return String(decoding: data, as: UTF8.self)
  }

  private func save() {
    if let data = try? JSONEncoder().encode(statistics) {
      defaults.set(data, forKey: Self.storageKey)
    }
    publish()
  }

  private func publish() {
    applications = statistics.applications.map { appID, record in
      ApplicationSummary(
        appID: appID, name: record.name, openings: record.openings,
        groupViews: record.groups.values.reduce(0, +),
        actionUses: record.actions.values.reduce(0, +))
    }.sorted { lhs, rhs in
      if lhs.openings != rhs.openings { return lhs.openings > rhs.openings }
      if lhs.name != rhs.name { return lhs.name < rhs.name }
      return lhs.appID < rhs.appID
    }
    totalOpenings = applications.reduce(0) { $0 + $1.openings }
    groupViews = applications.reduce(0) { $0 + $1.groupViews }
    actionUses = applications.reduce(0) { $0 + $1.actionUses }
  }
}

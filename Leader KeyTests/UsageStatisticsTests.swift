import Foundation
import XCTest

@testable import Leader_Key

final class UsageStatisticsTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suiteName: String!

  override func setUp() {
    super.setUp()
    suiteName = "KeywinkUsageStatisticsTests-\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)!
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  func testPersistsAggregatesAndSeparatesApplicationContexts() throws {
    let statistics = UsageStatistics(defaults: defaults)
    statistics.recordOpening(appID: "editor", appName: "Editor")
    statistics.recordGroup(path: ["g"], appID: "editor")
    statistics.recordAction(path: ["g", "t"], appID: "editor")
    statistics.recordOpening(appID: "browser", appName: "Browser")
    statistics.recordOpening(appID: "browser", appName: "Browser")
    statistics.recordGroup(path: ["g"], appID: "browser")

    let restored = UsageStatistics(defaults: defaults)
    XCTAssertEqual(restored.totalOpenings, 3)
    XCTAssertEqual(restored.groupViews, 2)
    XCTAssertEqual(restored.actionUses, 1)
    XCTAssertEqual(restored.count(path: ["g"]), 2)
    XCTAssertEqual(restored.count(path: ["g", "t"], appID: "editor"), 1)
    XCTAssertEqual(restored.count(path: ["g", "t"], appID: "browser"), 0)
    let editor = try XCTUnwrap(restored.applications.first { $0.appID == "editor" })
    XCTAssertEqual(editor.name, "Editor")
    XCTAssertEqual(editor.openings, 1)
    XCTAssertEqual(editor.groupViews, 1)
    XCTAssertEqual(editor.actionUses, 1)
  }

  func testNestedPathsDoNotCollideAndSurviveConfigurationReload() throws {
    let statistics = UsageStatistics(defaults: defaults)
    statistics.recordAction(path: ["g", "t"], appID: "editor")
    statistics.recordAction(path: ["g/t"], appID: "editor")
    statistics.recordAction(path: ["g/t"], appID: "editor")
    statistics.recordGroup(path: ["g", "nested", "t"], appID: "editor")
    XCTAssertEqual(statistics.count(path: ["g", "t"]), 1)
    XCTAssertEqual(statistics.count(path: ["g/t"]), 2)
    XCTAssertEqual(statistics.count(path: ["g", "nested", "t"]), 1)
    XCTAssertEqual(statistics.count(path: ["other", "t"]), 0)

    let items = [action("b"), action("t")]
    let decoded = try JSONDecoder().decode(
      [ActionOrGroup].self, from: JSONEncoder().encode(items))
    XCTAssertNotEqual(items[1].uiid, decoded[1].uiid)
    XCTAssertEqual(
      statistics.ranked(decoded, parentPath: ["g"]).map { $0.item.key }, ["t", "b"])
  }

  func testRankingUsesApplicationHistoryWithOverallFallbackAndStableTies() {
    let statistics = UsageStatistics(defaults: defaults)
    let items = [action("a"), action("b"), action("c"), action("d")]
    statistics.recordAction(path: ["g", "c"], appID: "editor")
    statistics.recordAction(path: ["g", "c"], appID: "editor")
    statistics.recordAction(path: ["g", "b"], appID: "browser")
    XCTAssertEqual(
      statistics.ranked(items, parentPath: ["g"], appID: "browser").map { $0.item.key },
      ["b", "a", "c", "d"])
    XCTAssertEqual(
      statistics.ranked(items, parentPath: ["g"], appID: "new-app").map { $0.item.key },
      ["c", "b", "a", "d"])
    XCTAssertEqual(
      statistics.ranked(items, parentPath: ["unused"], appID: "editor").map { $0.item.key },
      ["a", "b", "c", "d"])
  }

  func testResetRemovesPersistedStatisticsWithoutRemovingOtherPreferences() {
    defaults.set("keep", forKey: "unrelatedPreference")
    let statistics = UsageStatistics(defaults: defaults)
    statistics.recordOpening(appID: "editor", appName: "Editor")
    statistics.recordGroup(path: ["g"], appID: "editor")
    statistics.recordAction(path: ["g", "t"], appID: "editor")
    statistics.reset()

    XCTAssertEqual(statistics.totalOpenings, 0)
    XCTAssertEqual(statistics.groupViews, 0)
    XCTAssertEqual(statistics.actionUses, 0)
    XCTAssertTrue(statistics.applications.isEmpty)
    XCTAssertEqual(UsageStatistics(defaults: defaults).count(path: ["g", "t"]), 0)
    XCTAssertNil(defaults.object(forKey: UsageStatistics.storageKey))
    XCTAssertEqual(defaults.string(forKey: "unrelatedPreference"), "keep")
  }

  func testMalformedStoredDataFallsBackToEmptyUsableStatistics() {
    defaults.set(Data("invalid JSON".utf8), forKey: UsageStatistics.storageKey)
    let statistics = UsageStatistics(defaults: defaults)
    XCTAssertEqual(statistics.totalOpenings, 0)
    XCTAssertTrue(statistics.applications.isEmpty)
    statistics.recordOpening(appID: "editor", appName: "Editor")
    XCTAssertEqual(UsageStatistics(defaults: defaults).totalOpenings, 1)
  }

  private func action(_ key: String) -> ActionOrGroup {
    .action(Action(key: key, type: .command, label: "Private label", value: "private-command"))
  }
}

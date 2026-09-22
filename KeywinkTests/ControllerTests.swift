import Cocoa
import Defaults
import XCTest

@testable import Keywink

final class ControllerTests: XCTestCase {
  private var directory: URL!
  private var config: UserConfig!
  private var controller: Controller!
  private var ranActions: [String] = []

  @MainActor
  override func setUpWithError() throws {
    try super.setUpWithError()
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let directoryPath = directory.path
    config = UserConfig(
      defaultDirectoryResolver: { directoryPath },
      configDirectoryReader: { directoryPath }, configDirectoryWriter: { _ in })
    let fixture = Data(
      """
      {"actions":[
        {"key":"x","type":"command","label":"No-op","value":":"},
        {"key":"y","type":"url","label":"Example","value":"https://example.com"}
      ]}
      """.utf8)
    try fixture.write(to: config.url)
    config.ensureAndLoad()
    let state = UserState(userConfig: config)
    controller = Controller(
      userState: state, userConfig: config,
      usage: UsageStatistics(defaults: UserDefaults(suiteName: "ControllerTests-\(UUID())")!),
      sourceApplication: { ("test.editor", "Editor") },
      actionRunner: { [weak self] action in self?.ranActions.append(action.value) })
    settle()
  }

  override func tearDownWithError() throws {
    controller.window?.orderOut(nil)
    controller = nil
    try? FileManager.default.removeItem(at: directory)
    try super.tearDownWithError()
  }

  @MainActor
  func testRepeatRunsTheLastActionAgain() {
    controller.repeatLastAction()
    XCTAssertEqual(ranActions, [], "nothing to repeat before an action ran")

    controller.show()
    settle()
    controller.handleKey("x", withModifiers: [])
    settle()
    XCTAssertEqual(ranActions, [":"])

    controller.repeatLastAction()
    XCTAssertEqual(ranActions, [":", ":"])
    XCTAssertEqual(controller.lastAction?.key, "x")
  }

  @MainActor
  func testStickyActionKeepsThePanelOpenWhileAnotherAppTakesFocus() {
    Defaults[.modifierKeyConfiguration] = .controlGroupOptionSticky
    controller.show()
    settle()

    controller.handleKey("y", withModifiers: [.option])
    XCTAssertEqual(ranActions, ["https://example.com"])
    XCTAssertTrue(controller.window.isVisible, "sticky mode keeps the panel open")
    XCTAssertTrue(controller.shouldStayOpenAfterResigningKey(now: Date()))
    XCTAssertFalse(
      controller.shouldStayOpenAfterResigningKey(
        now: Date().addingTimeInterval(Controller.stickyGracePeriod + 1)),
      "the grace period ends so a deliberate focus change still hides the panel")

    controller.windowDidResignKey()
    settle()
    XCTAssertTrue(controller.window.isVisible, "losing key status inside the grace period")

    controller.hide()
    settle()
    XCTAssertFalse(controller.shouldStayOpenAfterResigningKey(now: Date()))
    XCTAssertFalse(controller.window.isVisible)
  }

  @MainActor
  func testNormalActionHidesThePanel() {
    controller.show()
    settle()
    controller.handleKey("x", withModifiers: [])
    settle()
    XCTAssertFalse(controller.window.isVisible)
    XCTAssertFalse(controller.shouldStayOpenAfterResigningKey(now: Date()))
  }

  func testIsSameApplicationComparesResolvedBundlePaths() {
    let safari = URL(fileURLWithPath: "/Applications/Safari.app")
    XCTAssertTrue(Controller.isSameApplication(safari, "/Applications/Safari.app/"))
    XCTAssertFalse(Controller.isSameApplication(safari, "/Applications/Mail.app"))
    XCTAssertFalse(Controller.isSameApplication(nil, "/Applications/Safari.app"))
  }

  private func settle() {
    let settled = expectation(description: "UI settled")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
    wait(for: [settled], timeout: 2)
  }
}

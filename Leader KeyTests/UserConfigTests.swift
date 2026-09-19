import XCTest

@testable import Leader_Key

class TestAlertManager: AlertHandler {
  var shownAlerts: [(style: NSAlert.Style, message: String)] = []

  func showAlert(style: NSAlert.Style, message: String) {
    shownAlerts.append((style: style, message: message))
  }

  func showAlert(
    style: NSAlert.Style, message: String, informativeText: String, buttons: [String]
  ) -> NSApplication.ModalResponse {
    shownAlerts.append((style: style, message: message))
    return .alertFirstButtonReturn
  }

  func reset() {
    shownAlerts = []
  }
}

private final class TestConfigDirectoryStore {
  var path: String

  init(path: String) {
    self.path = path
  }
}

final class UserConfigTests: XCTestCase {
  var tempBaseDir: String!
  var testDefaultDir: String!
  var testAlertManager: TestAlertManager!
  var subject: UserConfig!
  private var configDirectoryStore: TestConfigDirectoryStore!

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Create a unique temporary directory for each test
    tempBaseDir = NSTemporaryDirectory().appending("/LeaderKeyTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      atPath: tempBaseDir, withIntermediateDirectories: true)
    testDefaultDir = tempBaseDir.appending("/DefaultConfigDir")

    configDirectoryStore = TestConfigDirectoryStore(path: tempBaseDir)

    testAlertManager = TestAlertManager()
    let isolatedDefaultDir = testDefaultDir!
    let configDirectoryStore = configDirectoryStore!
    subject = UserConfig(
      alertHandler: testAlertManager,
      defaultDirectoryResolver: {
        try? FileManager.default.createDirectory(
          atPath: isolatedDefaultDir, withIntermediateDirectories: true)
        return isolatedDefaultDir
      },
      configDirectoryReader: { configDirectoryStore.path },
      configDirectoryWriter: { configDirectoryStore.path = $0 })
  }

  override func tearDownWithError() throws {
    subject = nil
    testAlertManager.reset()
    try FileManager.default.removeItem(atPath: tempBaseDir)
    configDirectoryStore = nil

    try super.tearDownWithError()
  }

  func testInitializesWithDefaults() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertNotEqual(subject.root, emptyRoot)
    XCTAssertTrue(subject.exists)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
  }

  func testCreatesDefaultConfigDirIfNotExists() throws {
    let defaultDir = testDefaultDir!
    configDirectoryStore.path = defaultDir

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertTrue(FileManager.default.fileExists(atPath: defaultDir))
    XCTAssertTrue(subject.exists)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
    XCTAssertNotEqual(subject.root, emptyRoot)  // Verify the config was parsed successfully
  }

  func testResetsToDefaultDirWhenCustomDirDoesNotExist() throws {
    let nonExistentDir = tempBaseDir.appending("/DoesNotExist")
    configDirectoryStore.path = nonExistentDir

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertEqual(configDirectoryStore.path, testDefaultDir)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 1)
    XCTAssertEqual(testAlertManager.shownAlerts[0].style, .warning)
    XCTAssertTrue(
      testAlertManager.shownAlerts[0].message.contains("Config directory does not exist"))
    XCTAssertTrue(subject.exists)
  }

  func testShowsAlertWhenConfigFileFailsToParse() throws {
    configDirectoryStore.path = testDefaultDir
    try FileManager.default.createDirectory(
      atPath: testDefaultDir, withIntermediateDirectories: true)

    let invalidJSON = "{ invalid json }"
    try invalidJSON.write(to: subject.url, atomically: true, encoding: .utf8)

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertEqual(subject.root, emptyRoot)
    XCTAssertGreaterThan(testAlertManager.shownAlerts.count, 0)
    // Verify that at least one warning alert was shown (JSON parsing errors are non-critical)
    XCTAssertTrue(
      testAlertManager.shownAlerts.contains { alert in
        alert.style == .warning
      })
  }

  func testValidationIssuesDoNotTriggerAlerts() throws {
    let json = """
      {
        "actions": [
          { "key": "a", "type": "application", "value": "/Applications/Safari.app" },
          { "key": "a", "type": "url", "value": "https://example.com" }
        ]
      }
      """

    try json.write(to: subject.url, atomically: true, encoding: .utf8)

    subject.ensureAndLoad()
    waitForConfigLoad()

    XCTAssertFalse(subject.validationErrors.isEmpty)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)

    testAlertManager.reset()
    subject.saveConfig()

    XCTAssertFalse(subject.validationErrors.isEmpty)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
  }

  func testRuntimeEnvironmentDetectsEveryXCTestMarker() {
    XCTAssertTrue(
      RuntimeEnvironment.isRunningTests(
        environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"],
        hasXCTestCaseClass: false))
    XCTAssertTrue(
      RuntimeEnvironment.isRunningTests(
        environment: ["XCTestSessionIdentifier": "test-session"],
        hasXCTestCaseClass: false))
    XCTAssertTrue(
      RuntimeEnvironment.isRunningTests(environment: [:], hasXCTestCaseClass: true))
    XCTAssertFalse(
      RuntimeEnvironment.isRunningTests(environment: [:], hasXCTestCaseClass: false))
  }

  func testDefaultDirectoryIsProcessIsolatedDuringTests() {
    let applicationSupportDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]

    XCTAssertTrue(RuntimeEnvironment.isRunningTests)
    XCTAssertEqual(UserConfig.defaultDirectory(), RuntimeEnvironment.testConfigDirectory)
    XCTAssertFalse(
      UserConfig.defaultDirectory().hasPrefix(applicationSupportDirectory.path + "/"))
  }

  private func waitForConfigLoad() {
    let expectation = expectation(description: "config load flush")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: 1.0)
  }
}

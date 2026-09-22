import XCTest

@testable import Keywink

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
    tempBaseDir = NSTemporaryDirectory().appending("/KeywinkTests-\(UUID().uuidString)")
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

  func testLaunchLoadPopulatesRootBeforeReturning() throws {
    configDirectoryStore.path = testDefaultDir
    try FileManager.default.createDirectory(
      atPath: testDefaultDir, withIntermediateDirectories: true)
    try configData(key: "o", value: "https://example.com").write(to: subject.url)

    // No waiting: a global shortcut may fire right after launch and must see the config.
    subject.ensureAndLoad()

    XCTAssertEqual(subject.root.actions.count, 1)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
  }

  func testGlobalGroupNavigationReplacesTheCurrentPath() {
    let nested = Group(key: "r", label: "Nested group", actions: [])
    let applications = Group(key: "g", label: "Applications", actions: [.group(nested)])
    let raycast = Group(key: "r", label: "Raycast", actions: [])
    subject.root = Group(
      key: nil,
      actions: [
        .group(applications), .group(raycast),
        .action(Action(key: "t", type: .command, value: "must not run")),
      ])
    let state = UserState(userConfig: subject)
    state.navigateToGroup(applications)
    state.navigateToGroup(nested)

    XCTAssertTrue(state.openRootGroup(for: "r"))
    XCTAssertEqual(state.navigationPath, [raycast])
    XCTAssertEqual(state.display, "r")
    XCTAssertTrue(state.openRootGroup(for: "g"))
    XCTAssertEqual(state.navigationPath, [applications])
    XCTAssertTrue(state.openRootGroup(for: "g"))
    XCTAssertEqual(state.navigationPath, [applications])

    XCTAssertFalse(state.openRootGroup(for: "t"))
    XCTAssertFalse(state.openRootGroup(for: "missing"))
    XCTAssertEqual(state.navigationPath, [applications])
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

  func testImportsValidConfigAndPreservesSourceAndBackup() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()

    let originalDestinationData = try Data(contentsOf: subject.url)
    let sourceURL = URL(fileURLWithPath: tempBaseDir)
      .appendingPathComponent("Leader Key config.json")
    let sourceData = configData(key: "x", value: "https://example.com/imported")
    try sourceData.write(to: sourceURL)
    let expectedRoot = try JSONDecoder().decode(Group.self, from: sourceData)

    let backupURL = try XCTUnwrap(subject.importConfig(from: sourceURL))

    XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
    XCTAssertEqual(try Data(contentsOf: subject.url), sourceData)
    XCTAssertEqual(try Data(contentsOf: backupURL), originalDestinationData)
    try assertSamePersistedConfig(subject.root, expectedRoot)
    XCTAssertTrue(subject.validationErrors.isEmpty)
  }

  func testRejectsInvalidImportWithoutChangingDestination() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()

    let originalDestinationData = try Data(contentsOf: subject.url)
    let originalRoot = subject.root
    let sourceURL = URL(fileURLWithPath: tempBaseDir)
      .appendingPathComponent("invalid-config.json")
    let sourceData = configData(keys: ["x", "x"])
    try sourceData.write(to: sourceURL)

    XCTAssertThrowsError(try subject.importConfig(from: sourceURL)) { error in
      guard case ConfigImportError.validationFailed = error else {
        return XCTFail("Expected validation failure, got \(error)")
      }
    }

    XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
    XCTAssertEqual(try Data(contentsOf: subject.url), originalDestinationData)
    XCTAssertEqual(subject.root, originalRoot)
    XCTAssertTrue(try backupURLs().isEmpty)
  }

  func testRejectsImportFromDestinationFile() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()
    let originalDestinationData = try Data(contentsOf: subject.url)

    XCTAssertThrowsError(try subject.importConfig(from: subject.url)) { error in
      guard case ConfigImportError.sourceMatchesDestination = error else {
        return XCTFail("Expected same-file rejection, got \(error)")
      }
    }

    XCTAssertEqual(try Data(contentsOf: subject.url), originalDestinationData)
    XCTAssertTrue(try backupURLs().isEmpty)
  }

  func testRejectsImportFromDestinationSymlink() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()
    let originalDestinationData = try Data(contentsOf: subject.url)
    let symlinkURL = URL(fileURLWithPath: tempBaseDir)
      .appendingPathComponent("current-config-link.json")
    try FileManager.default.createSymbolicLink(
      at: symlinkURL, withDestinationURL: subject.url)

    XCTAssertThrowsError(try subject.importConfig(from: symlinkURL)) { error in
      guard case ConfigImportError.sourceMatchesDestination = error else {
        return XCTFail("Expected same-file rejection, got \(error)")
      }
    }

    XCTAssertEqual(try Data(contentsOf: subject.url), originalDestinationData)
    XCTAssertTrue(try backupURLs().isEmpty)
  }

  func testRejectsMalformedImportWithoutChangingDestination() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()
    let originalDestinationData = try Data(contentsOf: subject.url)
    let sourceURL = URL(fileURLWithPath: tempBaseDir)
      .appendingPathComponent("malformed-config.json")
    let malformedData = Data("{ malformed json }".utf8)
    try malformedData.write(to: sourceURL)

    XCTAssertThrowsError(try subject.importConfig(from: sourceURL))

    XCTAssertEqual(try Data(contentsOf: sourceURL), malformedData)
    XCTAssertEqual(try Data(contentsOf: subject.url), originalDestinationData)
    XCTAssertTrue(try backupURLs().isEmpty)
  }

  func testImportCancelsQueuedAutosave() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()

    let sourceURL = URL(fileURLWithPath: tempBaseDir)
      .appendingPathComponent("import-after-edit.json")
    let sourceData = configData(key: "i", value: "https://example.com/imported")
    try sourceData.write(to: sourceURL)

    subject.root = try JSONDecoder().decode(
      Group.self,
      from: configData(key: "q", value: "https://example.com/queued"))
    try subject.importConfig(from: sourceURL)
    waitForAsyncIO()

    XCTAssertEqual(try Data(contentsOf: subject.url), sourceData)
    XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
  }

  func testImportSupersedesInFlightReload() throws {
    subject.ensureAndLoad()
    waitForConfigLoad()

    let staleData = configData(key: "s", value: "https://example.com/stale")
    try staleData.write(to: subject.url, options: .atomic)
    subject.reloadFromFile()

    let sourceURL = URL(fileURLWithPath: tempBaseDir)
      .appendingPathComponent("import-after-reload.json")
    let sourceData = configData(key: "n", value: "https://example.com/new")
    try sourceData.write(to: sourceURL)
    let expectedRoot = try JSONDecoder().decode(Group.self, from: sourceData)
    try subject.importConfig(from: sourceURL)
    waitForAsyncIO()

    XCTAssertEqual(try Data(contentsOf: subject.url), sourceData)
    try assertSamePersistedConfig(subject.root, expectedRoot)
  }

  // MARK: - TOML

  func testLoadsAndSavesTomlWhenThatFileExists() throws {
    configDirectoryStore.path = testDefaultDir
    try FileManager.default.createDirectory(
      atPath: testDefaultDir, withIntermediateDirectories: true)
    let toml = """
      # Keywink configuration
      type = "group"

      [[actions]]
      key = "o"
      type = "url"
      label = "Example"
      value = "https://example.com"

      [[actions]]
      key = "g"
      type = "group"

        [[actions.actions]]
        key = "t"
        type = "command"
        value = "echo hi"
      """
    try toml.write(
      toFile: (testDefaultDir as NSString).appendingPathComponent("config.toml"), atomically: true,
      encoding: .utf8)

    subject.ensureAndLoad()

    XCTAssertEqual(subject.format, .toml)
    XCTAssertEqual(subject.url.lastPathComponent, "config.toml")
    XCTAssertEqual(subject.root.actions.count, 2)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
    guard case .group(let group) = subject.root.actions[1],
      case .action(let nested) = group.actions[0]
    else { return XCTFail("expected a nested command") }
    XCTAssertEqual(nested.value, "echo hi")

    subject.root = Group(
      key: nil, actions: [.action(Action(key: "x", type: .command, value: "echo saved"))])
    waitForAsyncIO()

    let saved = try String(contentsOf: subject.url, encoding: .utf8)
    XCTAssertTrue(saved.contains("[[actions]]"), saved)
    XCTAssertTrue(saved.contains("echo saved"), saved)
    try assertSamePersistedConfig(try UserConfig.decode(saved, as: .toml), subject.root)
  }

  func testConvertsBetweenJsonAndTomlKeepingABackup() throws {
    subject.ensureAndLoad()
    XCTAssertEqual(subject.format, .json)
    let original = subject.root
    let jsonURL = subject.url

    let backupURL = try XCTUnwrap(subject.convert(to: .toml))

    XCTAssertEqual(subject.format, .toml)
    XCTAssertTrue(FileManager.default.fileExists(atPath: subject.url.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path))
    XCTAssertTrue(backupURL.lastPathComponent.hasPrefix("config.json.backup-"))
    XCTAssertNil(try subject.convert(to: .toml), "converting to the current format is a no-op")

    subject.reloadFromFile()
    waitForConfigLoad()
    XCTAssertEqual(subject.format, .toml)
    try assertSamePersistedConfig(subject.root, original)

    try subject.convert(to: .json)
    XCTAssertEqual(subject.format, .json)
    XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path))
    try assertSamePersistedConfig(
      try JSONDecoder().decode(Group.self, from: Data(contentsOf: jsonURL)), original)
  }

  func testImportIntoTomlConfigWritesToml() throws {
    subject.ensureAndLoad()
    try subject.convert(to: .toml)
    let sourceURL = URL(fileURLWithPath: tempBaseDir).appendingPathComponent("leader.json")
    try configData(key: "x", value: "https://example.com/imported").write(to: sourceURL)

    try subject.importConfig(from: sourceURL)

    let written = try String(contentsOf: subject.url, encoding: .utf8)
    XCTAssertTrue(written.contains("[[actions]]"), written)
    XCTAssertTrue(written.contains("https://example.com/imported"), written)
    XCTAssertEqual(subject.root.actions.count, 1)
  }

  func testLoadsKdlConfigAndConvertsBackToJson() throws {
    configDirectoryStore.path = testDefaultDir
    try FileManager.default.createDirectory(
      atPath: testDefaultDir, withIntermediateDirectories: true)
    try """
    group "o" label="Open" {
        url "g" "https://example.com"
    }
    """.write(
      toFile: (testDefaultDir as NSString).appendingPathComponent("config.kdl"), atomically: true,
      encoding: .utf8)

    subject.ensureAndLoad()

    XCTAssertEqual(subject.format, .kdl)
    XCTAssertEqual(subject.root.actions.count, 1)
    XCTAssertEqual(testAlertManager.shownAlerts.count, 0)
    let original = subject.root

    subject.root = Group(
      key: nil, actions: [.action(Action(key: "x", type: .command, value: "echo saved"))])
    waitForAsyncIO()
    let saved = try String(contentsOf: subject.url, encoding: .utf8)
    XCTAssertTrue(saved.contains("command \"x\" \"echo saved\""), saved)

    subject.root = original
    waitForAsyncIO()
    let backup = try XCTUnwrap(subject.convert(to: .json))
    XCTAssertTrue(backup.lastPathComponent.hasPrefix("config.kdl.backup-"))
    XCTAssertEqual(subject.format, .json)
    try assertSamePersistedConfig(
      try JSONDecoder().decode(Group.self, from: Data(contentsOf: subject.url)), original)
  }

  func testImportsTomlAndKdlSourcesIntoTheCurrentFormat() throws {
    subject.ensureAndLoad()
    XCTAssertEqual(subject.format, .json)

    let kdlSource = URL(fileURLWithPath: tempBaseDir).appendingPathComponent("other.kdl")
    try "url \"k\" \"https://example.com/kdl\"\n".write(
      to: kdlSource, atomically: true, encoding: .utf8)
    try subject.importConfig(from: kdlSource)
    XCTAssertEqual(subject.url.lastPathComponent, "config.json")
    XCTAssertTrue(
      try String(contentsOf: subject.url, encoding: .utf8).contains("https://example.com/kdl"))

    let tomlSource = URL(fileURLWithPath: tempBaseDir).appendingPathComponent("other.toml")
    try """
    type = "group"
    [[actions]]
    key = "t"
    type = "url"
    value = "https://example.com/toml"
    """.write(to: tomlSource, atomically: true, encoding: .utf8)
    try subject.importConfig(from: tomlSource)
    XCTAssertTrue(
      try String(contentsOf: subject.url, encoding: .utf8).contains("https://example.com/toml"))
    XCTAssertEqual(subject.root.actions.count, 1)

    let unsupported = URL(fileURLWithPath: tempBaseDir).appendingPathComponent("other.yaml")
    try "actions: []".write(to: unsupported, atomically: true, encoding: .utf8)
    XCTAssertThrowsError(try subject.importConfig(from: unsupported))
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

  private func waitForAsyncIO() {
    let expectation = expectation(description: "asynchronous config I/O flush")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)
  }

  private func configData(key: String, value: String) -> Data {
    configData(keys: [key], value: value)
  }

  private func configData(keys: [String], value: String = "https://example.com") -> Data {
    let actions = keys.map {
      "{ \"key\": \"\($0)\", \"type\": \"url\", \"value\": \"\(value)\" }"
    }.joined(separator: ",")
    return Data("{ \"type\": \"group\", \"actions\": [\(actions)] }".utf8)
  }

  private func backupURLs() throws -> [URL] {
    try FileManager.default.contentsOfDirectory(
      at: subject.url.deletingLastPathComponent(),
      includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasPrefix("config.json.backup-") }
  }

  private func assertSamePersistedConfig(
    _ first: Group, _ second: Group, file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    XCTAssertEqual(
      try encoder.encode(first), try encoder.encode(second), file: file, line: line)
  }
}

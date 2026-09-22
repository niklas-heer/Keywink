import XCTest

@testable import Keywink

final class URLSchemeTests: XCTestCase {

  // MARK: - Configuration Management Tests

  func testConfigReloadURL() {
    let url = URL(string: "keywink://config-reload")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .configReload)
  }

  func testConfigRevealURL() {
    let url = URL(string: "keywink://config-reveal")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .configReveal)
  }

  // MARK: - Window Control Tests

  func testActivateURL() {
    let url = URL(string: "keywink://activate")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .activate)
  }

  func testHideURL() {
    let url = URL(string: "keywink://hide")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .hide)
  }

  func testRepeatURL() {
    let url = URL(string: "keywink://repeat")!
    XCTAssertEqual(URLSchemeHandler.parse(url), .repeatLastAction)
  }

  func testResetURL() {
    let url = URL(string: "keywink://reset")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .reset)
  }

  // MARK: - Settings & Info Tests

  func testSettingsURL() {
    let url = URL(string: "keywink://settings")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .settings)
  }

  func testAboutURL() {
    let url = URL(string: "keywink://about")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .about)
  }

  // MARK: - Navigation Tests

  func testNavigateWithKeys() {
    let url = URL(string: "keywink://navigate?keys=a,b,c")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["a", "b", "c"], execute: true))
  }

  func testNavigateWithExecuteFalse() {
    let url = URL(string: "keywink://navigate?keys=a,b&execute=false")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["a", "b"], execute: false))
  }

  func testNavigateWithExecuteTrue() {
    let url = URL(string: "keywink://navigate?keys=x,y&execute=true")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["x", "y"], execute: true))
  }

  func testNavigateWithSingleKey() {
    let url = URL(string: "keywink://navigate?keys=z")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .navigate(keys: ["z"], execute: true))
  }

  func testNavigateWithoutKeys() {
    let url = URL(string: "keywink://navigate")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }

  // MARK: - Invalid URL Tests

  func testInvalidScheme() {
    let url = URL(string: "invalid://settings")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .invalid)
  }

  func testSchemeAndCommandAreCaseInsensitive() {
    XCTAssertEqual(URLSchemeHandler.parse(URL(string: "KEYWINK://HIDE")!), .hide)
  }

  func testLeaderKeySchemeIsNotHandled() {
    XCTAssertEqual(URLSchemeHandler.parse(URL(string: "leaderkey://activate")!), .invalid)
  }

  func testBuiltAppUsesKeywinkIdentity() throws {
    let app = Bundle(for: AppDelegate.self)
    XCTAssertEqual(app.bundleIdentifier, "de.niklas-heer.Keywink")
    XCTAssertEqual(app.object(forInfoDictionaryKey: "CFBundleName") as? String, "Keywink")
    let urlTypes = try XCTUnwrap(
      app.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
    XCTAssertEqual(urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }, ["keywink"])
  }

  func testUpdatesRequireHTTPSFeedAndPublicKey() {
    let publicKey = Data(repeating: 1, count: 32).base64EncodedString()
    XCTAssertFalse(AppDelegate.hasUpdateConfiguration([:]))
    XCTAssertFalse(AppDelegate.hasUpdateConfiguration(["SUFeedURL": "", "SUPublicEDKey": ""]))
    XCTAssertFalse(
      AppDelegate.hasUpdateConfiguration([
        "SUFeedURL": "http://example.com/appcast.xml", "SUPublicEDKey": publicKey,
      ]))
    XCTAssertFalse(
      AppDelegate.hasUpdateConfiguration([
        "SUFeedURL": "https://example.com/appcast.xml", "SUPublicEDKey": "not-a-public-key",
      ]))
    XCTAssertTrue(
      AppDelegate.hasUpdateConfiguration([
        "SUFeedURL": "https://example.com/appcast.xml", "SUPublicEDKey": publicKey,
      ]))
  }

  func testUnknownHost() {
    let url = URL(string: "keywink://unknown")!
    let action = URLSchemeHandler.parse(url)
    XCTAssertEqual(action, .show)
  }
}

import XCTest
import UIKit
@testable import TiXing

private final class ObservabilityProviderSpy: ObservabilityProvider {
    let name = "Spy"
    private(set) var activated = false
    private(set) var events: [ObservabilityEvent] = []
    private(set) var errors: [ObservabilityErrorReport] = []

    func activate() { activated = true }
    func track(_ event: ObservabilityEvent) { events.append(event) }
    func reportError(_ report: ObservabilityErrorReport) { errors.append(report) }
}

final class ObservabilityTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        if let suiteName = observedTestSuiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
    }

    private var observedTestSuiteName: String?

    func testSanitizerNormalizesEventAndMasksSensitiveValues() {
        let event = ObservabilityEvent(kind: .metric, name: "AI Request/耗时", attributes: [
            "api_key": "secret",
            "api_key_hint": "secret",
            "question": "孩子的问题",
            "image_url": "/tmp/photo.jpg",
            "success": "1",
            "token": "Bearer abc123",
            "duration_ms": "128"
        ])
        let attributes = event.sanitizedAttributes

        XCTAssertEqual(event.sanitizedID, "metric_ai_request")
        XCTAssertEqual(attributes["success"], "1")
        XCTAssertEqual(attributes["duration_ms"], "128")
        XCTAssertNil(attributes["api_key"])
        XCTAssertNil(attributes["api_key_hint"])
        XCTAssertNil(attributes["question"])
        XCTAssertNil(attributes["image_url"])
        XCTAssertNil(attributes["token"])
    }

    func testUIApplicationDelegateExposesCompatibilityWindowSelector() {
        // Umeng U-APM monitors window-level presentations (for example PhotosPicker)
        // through UIApplicationDelegate.window. SwiftUI's default internal delegate
        // does not implement it, which previously caused an NSException.
        let delegate = UIApplication.shared.delegate
        XCTAssertNotNil(delegate)
        XCTAssertTrue(delegate?.responds(to: NSSelectorFromString("window")) == true)
    }

    func testServiceDoesNotSendBeforeConsentAndSendsAfterConsent() throws {
        let suiteName = "ObservabilityTests-\(UUID().uuidString)"
        observedTestSuiteName = suiteName
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let spy = ObservabilityProviderSpy()
        let service = ObservabilityService(defaults: defaults,
                                           config: ObservabilityConfig(buglyAppID: "", buglyAppKey: ""),
                                           providers: [spy])

        service.track(kind: .behavior, name: "capture")
        XCTAssertFalse(spy.activated)
        XCTAssertTrue(spy.events.isEmpty)

        service.setConsent(.granted)
        XCTAssertTrue(spy.activated)

        service.track(kind: .behavior, name: "capture")
        XCTAssertEqual(spy.events.map(\.sanitizedID), ["behavior_telemetry_consent", "behavior_capture"])
        let savedConsent = try XCTUnwrap(defaults.string(forKey: "tixing.observability.consent"))
        XCTAssertEqual(ObservabilityConsent(rawValue: savedConsent), .granted)
    }

    func testDeniedConsentNeverActivatesProviders() throws {
        let suiteName = "ObservabilityTests-Denied-\(UUID().uuidString)"
        observedTestSuiteName = suiteName
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let spy = ObservabilityProviderSpy()
        let service = ObservabilityService(defaults: defaults,
                                           config: ObservabilityConfig(buglyAppID: "", buglyAppKey: ""),
                                           providers: [spy])
        service.setConsent(.denied)
        service.track(kind: .metric, name: "review_submit")
        XCTAssertFalse(spy.activated)
        XCTAssertTrue(spy.events.isEmpty)
    }
}

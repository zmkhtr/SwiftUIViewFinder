import XCTest

final class UIKitDemoUITests: XCTestCase {
    func testInspectorTracksSwiftUIHostedByUIKit() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["UIKitHomeViewController"].waitForExistence(timeout: 5))

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["SwiftUITabScreen"].waitForExistence(timeout: 5))

        app.tabBars.buttons.element(boundBy: 0).tap()
        app.buttons["Push SwiftUI Screen"].tap()
        XCTAssertTrue(app.navigationBars["Hosted SwiftUI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PushedSwiftUIScreen"].waitForExistence(timeout: 5))
    }
}

// UI tests that drive the touches the recordings need (idb cannot: its
// swipe ignores --duration). Coordinates are window points, iPhone 17 Pro.
import XCTest

final class ProbeUITests: XCTestCase {
    private func launch(_ page: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-page", page]
        app.launch()
        sleep(3)
        return app
    }

    private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    // Press Home, hold, drag slowly to Settings, hold, release; then a quick
    // drag back to Search.
    func testTabDrag() {
        let app = launch("tabdrag")
        point(app, 70, 822).press(forDuration: 0.6, thenDragTo: point(app, 330, 822),
                                  withVelocity: XCUIGestureVelocity(150), thenHoldForDuration: 0.8)
        sleep(2)
        point(app, 330, 822).press(forDuration: 0.3, thenDragTo: point(app, 160, 822),
                                   withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.2)
        sleep(2)
    }

    // Long-press the interactive glass shape, then the glass button.
    func testPress() {
        let app = launch("press")
        point(app, 201, 396).press(forDuration: 1.5)
        sleep(2)
        let b = app.buttons["Glass Button"]
        if b.exists { b.press(forDuration: 1.5) }
        sleep(2)
    }
}

import XCTest

extension XCTestCase {
    /// Launches the app; `reset` starts from an empty library (debug builds only).
    @MainActor func launch(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        if reset { app.launchArguments = ["-resetLibrary"] }
        app.launch()
        return app
    }

    /// Opens a new design from the vehicle catalog, scrolling to the body style if needed.
    @MainActor func startDesign(_ app: XCUIApplication, car: String) {
        // The home screen always lists every vehicle below the saved designs.
        let chip = app.buttons["car-\(car)"].firstMatch
        for _ in 0..<6 where !chip.isHittable { app.swipeUp() }
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        XCTAssertTrue(app.buttons["exportPNG"].waitForExistence(timeout: 5))
    }

    /// A point in template pixels on the fitted template (`fillSurface` or `paintCanvas`).
    @MainActor func templatePoint(_ element: XCUIElement, x: CGFloat, y: CGFloat,
                                  template: CGSize = CGSize(width: 1024, height: 1024)) -> XCUICoordinate {
        let frame = element.frame
        return element.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.width * x / template.width, dy: frame.height * y / template.height))
    }

    /// Renames the open design through its title and waits for the new name to show.
    @MainActor func rename(_ app: XCUIApplication, to name: String) {
        app.buttons["designTitle"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + name)
        // The keyboard slides in and lifts the alert; tap Save once it has settled.
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        app.alerts.buttons["Save"].tap()
        let renamed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", name),
                                                object: app.buttons["designTitle"])
        XCTAssertEqual(XCTWaiter().wait(for: [renamed], timeout: 5), .completed)
    }

    @MainActor func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

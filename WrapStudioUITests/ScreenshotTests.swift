import XCTest

/// Builds a small showcase library and captures the README screenshots. Skipped unless run
/// with `TEST_RUNNER_WRAP_SCREENSHOTS=1`; the images are attached to the test result.
final class ScreenshotTests: XCTestCase {
    @MainActor func testReadmeScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WRAP_SCREENSHOTS"] == "1",
                          "Set TEST_RUNNER_WRAP_SCREENSHOTS=1 to capture README screenshots.")
        continueAfterFailure = false
        let app = launch()

        // Cybertruck: graphite with crimson panels, mirrored top to bottom.
        startDesign(app, car: "ct")
        fill(app, body: "7D838C", panels: [(335, 85), (537, 92)], color: "B3121F",
             template: CGSize(width: 1024, height: 768))
        rename(app, to: "Desert Storm")
        goBack(app)

        // Model Y 2025+: cyan with black doors.
        startDesign(app, car: "my-2025")
        fill(app, body: "4FC3D9", panels: [(225, 446), (230, 642)], color: "0B0B0D")
        rename(app, to: "Glacier")
        goBack(app)

        // Model 3 2024+: navy with amber hood and doors, and a racing number.
        startDesign(app, car: "m3-2024")
        app.buttons["addText"].tap()
        let field = app.textFields["textStickerField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("42")
        app.buttons["addTextSticker"].tap()
        fill(app, body: "1E3A8A", panels: [(162, 435), (170, 651), (512, 281)], color: "FFB547")
        rename(app, to: "Midnight Racer")
        capture(app, name: "editor")

        app.buttons["exportPNG"].tap()
        XCTAssertTrue(app.navigationBars["Export wrap"].waitForExistence(timeout: 5))
        capture(app, name: "export")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Export wrap"].waitForNonExistence(timeout: 5))
        goBack(app)
        // Finding vehicle chips scrolled the gallery; its lazy grid only builds visible cards.
        let card = app.buttons["design-Midnight Racer"]
        for _ in 0..<4 where !card.exists { app.swipeDown() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        capture(app, name: "gallery")
    }

    /// Paints the whole body, then fills panels (and their mirror twins) in a second colour.
    @MainActor private func fill(_ app: XCUIApplication, body: String, panels: [(CGFloat, CGFloat)], color: String,
                                 template: CGSize = CGSize(width: 1024, height: 1024)) {
        app.buttons["tool-fill"].tap()
        app.buttons["color-\(body)"].tap()
        app.buttons["fillBody"].tap()
        app.buttons["mirrorToggle"].tap()
        app.buttons["color-\(color)"].tap()
        let surface = app.descendants(matching: .any)["fillSurface"].firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        for (x, y) in panels { templatePoint(surface, x: x, y: y, template: template).tap() }
    }

    @MainActor private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }
}

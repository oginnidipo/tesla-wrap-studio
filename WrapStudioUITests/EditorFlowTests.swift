import XCTest

final class EditorFlowTests: XCTestCase {
    @MainActor func testVehicleSelectionFillUndoExportAndAutosave() throws {
        let app = XCUIApplication()
        app.launch()
        capture(app, name: "Vehicle picker")
        for name in ["Cybertruck", "Model Y", "Model 3"] {
            let vehicle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Design a \(name) wrap.")).firstMatch
            if !vehicle.isHittable { app.swipeUp() }
            XCTAssertTrue(vehicle.waitForExistence(timeout: 5))
            vehicle.tap()
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5))
            let fill = app.buttons["fill-F14B35"]
            XCTAssertTrue(fill.waitForExistence(timeout: 5))
            if fill.isSelected { app.buttons["fill-558BC7"].tap() }
            else { fill.tap() }
            let export = app.buttons["exportPNG"]
            XCTAssertTrue(export.isEnabled)
            XCTAssertTrue(app.buttons["undo"].isEnabled)
            if name == "Model 3" { capture(app, name: "Model 3 editor") }
            export.tap()
            XCTAssertTrue(app.navigationBars["Export wrap"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["saveToFiles"].exists)
            if name == "Model 3" { capture(app, name: "Export PNG") }
            app.buttons["Done"].tap()
            app.buttons["undo"].tap()
            XCTAssertTrue(app.buttons["redo"].isEnabled)
            app.buttons["redo"].tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.terminate()
        app.launch()
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Design a Cybertruck wrap.")).firstMatch.tap()
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor func testPaintingSurvivesRotationAndCanBeUndone() {
        let app = XCUIApplication()
        app.launch()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Design a Model 3 wrap.")).firstMatch.tap()
        if app.buttons["exportPNG"].isEnabled {
            app.buttons["More"].tap()
            app.buttons["Clear design"].tap()
            app.buttons["Clear design"].tap()
        }
        let noFill = app.buttons["No body fill"]
        XCTAssertTrue(noFill.waitForExistence(timeout: 5))
        noFill.tap()
        let canvas = app.descendants(matching: .any)["paintCanvas"].firstMatch
        XCTAssertTrue(canvas.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.4))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6)))
        let undo = app.buttons["undo"]
        XCTAssertTrue(undo.isEnabled)
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCUIDevice.shared.orientation = .portrait
        app.buttons["exportPNG"].tap()
        XCTAssertTrue(app.navigationBars["Export wrap"].waitForExistence(timeout: 5))
        app.buttons["saveToFiles"].tap()
        let save = app.buttons["DOCPicker.actionButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.staticTexts["Your PNG was saved to Files."].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        undo.tap()
        XCTAssertFalse(app.buttons["exportPNG"].isEnabled)
        app.buttons["redo"].tap()
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
        capture(app, name: "Paint stroke after rotation")
    }
}

import XCTest

final class EditorFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor func testCreatePaintExportAndReopenDesign() throws {
        let app = launch()
        capture(app, name: "Empty gallery")
        startDesign(app, car: "m3-2024")
        XCTAssertFalse(app.buttons["exportPNG"].isEnabled)
        app.buttons["tool-fill"].tap()
        app.buttons["color-558BC7"].tap()
        app.buttons["fillBody"].tap()
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        capture(app, name: "Editor with body fill")

        app.buttons["exportPNG"].tap()
        XCTAssertTrue(app.navigationBars["Export wrap"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["exportFileName"].label, "File name Model 3 Wrap")
        XCTAssertTrue(app.buttons["saveToFiles"].exists)
        XCTAssertTrue(app.buttons["saveToPhotos"].exists)
        capture(app, name: "Export PNG")
        app.buttons["Done"].tap()

        app.buttons["undo"].tap()
        XCTAssertFalse(app.buttons["exportPNG"].isEnabled)
        app.buttons["redo"].tap()
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let card = app.buttons["design-Model 3 Wrap"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        capture(app, name: "Gallery")
        app.terminate()

        let relaunched = launch(reset: false)
        let saved = relaunched.buttons["design-Model 3 Wrap"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(relaunched.buttons["exportPNG"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.buttons["exportPNG"].isEnabled)
    }

    @MainActor func testLeavingAnEmptyNewDesignDiscardsIt() {
        let app = launch()
        startDesign(app, car: "ct")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["car-ct"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["design-Cybertruck Wrap"].exists)
    }

    @MainActor func testPanelFillMirrorsAndUndoes() {
        let app = launch()
        startDesign(app, car: "m3")
        app.buttons["tool-fill"].tap()
        app.buttons["mirrorToggle"].tap()
        let panels = app.descendants(matching: .any)["fillSurface"].firstMatch
        XCTAssertTrue(panels.waitForExistence(timeout: 5))
        // Left front door of the 2017–2023 Model 3 template.
        templatePoint(panels, x: 140, y: 480).tap()
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
        capture(app, name: "Mirrored panel fill")
        app.buttons["undo"].tap()
        XCTAssertFalse(app.buttons["exportPNG"].isEnabled)
        // The glass roof is not a panel.
        templatePoint(panels, x: 512, y: 560).tap()
        XCTAssertTrue(app.staticTexts["notice"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["exportPNG"].isEnabled)
    }

    @MainActor func testLetteringStickerCanBeAddedAndRemoved() {
        let app = launch()
        startDesign(app, car: "my-2025")
        app.buttons["addText"].tap()
        let field = app.textFields["textStickerField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("42")
        app.buttons["addTextSticker"].tap()
        let sticker = app.descendants(matching: .any)["sticker"].firstMatch
        XCTAssertTrue(sticker.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
        capture(app, name: "Lettering sticker")
        app.buttons["deleteSticker"].tap()
        XCTAssertFalse(sticker.exists)
        XCTAssertFalse(app.buttons["exportPNG"].isEnabled)
    }

    @MainActor func testPaintingSurvivesRotationAndSavesToFiles() {
        let app = launch()
        startDesign(app, car: "m3")
        let canvas = app.descendants(matching: .any)["paintCanvas"].firstMatch
        XCTAssertTrue(canvas.exists)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.4))
            .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6)))
        let undo = app.buttons["undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        XCTAssertTrue(undo.isEnabled)
        XCTAssertTrue(app.buttons["exportPNG"].isEnabled)
        XCUIDevice.shared.orientation = .landscapeLeft
        capture(app, name: "Landscape editor")
        XCUIDevice.shared.orientation = .portrait

        // Exports are named after the design; a unique name keeps earlier runs' files from
        // triggering the system's Replace prompt, and exercises renaming.
        let name = "Files Test \(Int(Date().timeIntervalSince1970) % 100_000)"
        rename(app, to: name)

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
    }

    @MainActor func testSavePNGToPhotos() {
        addUIInterruptionMonitor(withDescription: "Photos add permission") { alert in
            let allow = alert.buttons["Allow"]
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        let app = launch()
        startDesign(app, car: "m3")
        app.buttons["tool-fill"].tap()
        app.buttons["fillBody"].tap()
        app.buttons["exportPNG"].tap()
        XCTAssertTrue(app.buttons["saveToPhotos"].waitForExistence(timeout: 5))
        app.buttons["saveToPhotos"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permission = springboard.alerts.firstMatch
        if permission.waitForExistence(timeout: 5) { permission.buttons["Allow"].tap() }
        else if app.alerts.buttons["Allow"].exists { app.alerts.buttons["Allow"].tap() }
        XCTAssertTrue(app.staticTexts["photoSaveConfirmation"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["saveToPhotos"].isEnabled)
        capture(app, name: "PNG saved to Photos")
    }
}

import XCTest

final class StopSetUITests: XCTestCase {
    @MainActor
    private func launch(arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["group-Office"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testDeparturesAndMaps() {
        let app = launch()
        capture("01-Saved-Groups")
        app.buttons["group-Office"].tap()
        let first = app.buttons["departure-preview-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue((first.value as? String ?? "").contains("Live"))
        XCTAssertTrue((app.buttons["departure-preview-3"].value as? String ?? "").contains("Scheduled"))
        capture("02-Departures")
        first.tap()
        XCTAssertTrue(app.navigationBars["Bus Location"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Location updated'")).firstMatch.waitForExistence(timeout: 5))
        capture("03-Bus-Location")
        app.buttons["Done"].tap()
        app.buttons["stops-map"].tap()
        XCTAssertTrue(app.navigationBars["Office Stops"].waitForExistence(timeout: 5))
        capture("04-Stops-Map")
        app.buttons["Done"].tap()
        app.buttons["stop-filter"].tap()
        app.buttons["1063 · Daldy Street/Gaunt Street"].tap()
        XCTAssertTrue(app.buttons["departure-preview-0"].exists)
        XCTAssertFalse(app.buttons["departure-preview-1"].exists)
    }

    @MainActor
    func testBusNumberFilter() {
        let app = launch()
        app.buttons["group-Office"].tap()
        XCTAssertTrue(app.buttons["departure-preview-0"].waitForExistence(timeout: 5))
        let filter = app.buttons["route-filter"]
        filter.tap()
        let nx2 = app.buttons["route-filter-NX2"]
        XCTAssertTrue(nx2.waitForExistence(timeout: 5))
        nx2.tap()
        XCTAssertEqual(nx2.value as? String, "Selected")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["departure-preview-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["departure-preview-4"].exists)
        XCTAssertFalse(app.buttons["departure-preview-1"].exists)
        XCTAssertFalse(app.buttons["departure-preview-2"].exists)
        XCTAssertFalse(app.buttons["departure-preview-3"].exists)

        filter.tap()
        app.buttons["route-filter-923"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["departure-preview-2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["departure-preview-0"].exists)
        XCTAssertTrue(app.buttons["departure-preview-4"].exists)
        XCTAssertFalse(app.buttons["departure-preview-1"].exists)
        capture("12-Multiple-Bus-Numbers")

        app.buttons["group-menu"].tap()
        app.buttons["Refresh"].tap()
        XCTAssertTrue(app.buttons["departure-preview-2"].exists)
        XCTAssertFalse(app.buttons["departure-preview-1"].exists)
        filter.tap()
        XCTAssertEqual(nx2.value as? String, "Selected")
        XCTAssertEqual(app.buttons["route-filter-923"].value as? String, "Selected")
        nx2.tap()
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["departure-preview-0"].exists)
        XCTAssertTrue(app.buttons["departure-preview-2"].exists)

        app.buttons["stop-filter"].tap()
        app.buttons["7037 · Daldy Street"].tap()
        XCTAssertTrue(app.staticTexts["No Matching Buses"].waitForExistence(timeout: 5))
        filter.tap()
        app.buttons["route-filter-CTY"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["departure-preview-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["departure-preview-5"].exists)
        XCTAssertFalse(app.buttons["departure-preview-2"].exists)
        XCTAssertFalse(app.buttons["departure-preview-3"].exists)

        filter.tap()
        app.buttons["route-filter-all"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["departure-preview-3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["departure-preview-0"].exists)
        app.buttons["stop-filter"].tap()
        app.buttons["All 2 Stops"].tap()
        XCTAssertTrue(app.buttons["departure-preview-0"].waitForExistence(timeout: 5))

        filter.tap()
        nx2.tap()
        nx2.tap()
        XCTAssertEqual(app.buttons["route-filter-all"].value as? String, "Selected")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["departure-preview-1"].exists)
    }

    @MainActor
    func testDepartureRefreshSetting() {
        let app = launch()
        app.buttons["Settings"].tap()
        let interval = app.buttons["departure-refresh-interval"]
        XCTAssertTrue(interval.waitForExistence(timeout: 5))
        XCTAssertTrue(interval.label.contains("Every 10 seconds"))
        interval.tap()
        app.buttons["Every 60 seconds"].tap()
        XCTAssertTrue(interval.label.contains("Every 60 seconds"))
        app.buttons["Done"].tap()

        app.buttons["group-Office"].tap()
        XCTAssertTrue(app.buttons["departure-preview-0"].waitForExistence(timeout: 5))
        app.buttons["group-menu"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(interval.waitForExistence(timeout: 5))
        XCTAssertTrue(interval.label.contains("Every 60 seconds"))
    }

    @MainActor
    func testCreateAndEditGroup() {
        let app = launch()
        app.buttons["new-group"].tap()
        let next = app.buttons["picker-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        capture("05-Choose-Stops")
        app.buttons["select-1063"].tap()
        XCTAssertTrue(next.isEnabled)
        app.buttons["select-7037"].tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()
        let name = app.textFields["group-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["save-group"].isEnabled)
        name.tap()
        name.typeText("Commute")
        app.buttons["save-group"].tap()
        XCTAssertTrue(app.buttons["group-Commute"].waitForExistence(timeout: 5))
        app.buttons["group-Commute"].tap()
        app.buttons["group-menu"].tap()
        app.buttons["Edit Group"].tap()
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        app.buttons["select-7037"].tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        capture("06-Edit-Group")
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "Evening")
        app.buttons["save-group"].tap()
        XCTAssertTrue(app.navigationBars["Evening"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["stop-filter"].label.contains("Stop 1063"))
        app.buttons["group-menu"].tap()
        app.buttons["Edit Group"].tap()
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["select-1063"].label, "Remove stop 1063")
        XCTAssertEqual(app.buttons["select-7037"].label, "Add stop 7037")
    }

    @MainActor
    func testCreateSingleStopGroup() {
        let app = launch()
        app.buttons["new-group"].tap()
        let next = app.buttons["picker-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        let stop = app.buttons["select-1063"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()
        XCTAssertTrue(next.isEnabled)
        stop.tap()
        XCTAssertFalse(next.isEnabled)
        stop.tap()
        next.tap()
        let name = app.textFields["group-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let save = app.buttons["save-group"]
        XCTAssertFalse(save.isEnabled)
        name.tap()
        name.typeText("Solo")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let group = app.buttons["group-Solo"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        XCTAssertTrue(group.label.contains("1 stop"))
        group.tap()
        let departure = app.buttons["departure-preview-0"]
        XCTAssertTrue(departure.waitForExistence(timeout: 5))
        XCTAssertTrue(departure.label.contains("stop 1063"))
        app.buttons["stops-map"].tap()
        XCTAssertTrue(app.navigationBars["Solo Stop"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchByStopNumber() {
        let app = launch()
        app.buttons["new-group"].tap()
        let field = app.searchFields["Search address or stop number"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["map-stop-4400"].exists)
        field.tap()
        field.typeText("1063")
        XCTAssertTrue(app.buttons["search-stop-1063"].waitForExistence(timeout: 5))

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "99999999")
        XCTAssertTrue(app.staticTexts["search-stops-heading"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["search-stop-1063"].exists)

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "4400\n")
        let result = app.buttons["search-stop-4400"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.buttons["map-stop-4400"].waitForExistence(timeout: 5))
        let add = app.buttons["select-4400"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.buttons["picker-next"].tap()
        let name = app.textFields["group-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Library")
        app.buttons["save-group"].tap()
        let group = app.buttons["group-Library"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        XCTAssertTrue(group.label.contains("4400"))
        group.tap()
        let departure = app.buttons["departure-preview-0"]
        XCTAssertTrue(departure.waitForExistence(timeout: 5))
        XCTAssertTrue(departure.label.contains("stop 4400"))
    }

    @MainActor
    func testStopNumberPrefixesAndAddressFallback() {
        let app = launch()
        app.buttons["new-group"].tap()
        let field = app.searchFields["Search address or stop number"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("7")
        XCTAssertTrue(app.buttons["search-stop-7037"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search-stop-7081"].exists)
        XCTAssertTrue(app.buttons["search-stop-7500"].exists)
        XCTAssertFalse(app.buttons["search-stop-1063"].exists)
        field.typeText("0")
        XCTAssertTrue(app.buttons["search-stop-7037"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search-stop-7081"].exists)
        XCTAssertFalse(app.buttons["search-stop-7500"].exists)
        field.typeText("3")
        XCTAssertTrue(app.buttons["search-stop-7037"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["search-stop-7081"].exists)

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "21")
        let address = app.buttons["search-address-21 Queen Street"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        let stop = app.buttons["search-stop-2100"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search-stop-2101"].exists)
        XCTAssertLessThan(stop.frame.minY, address.frame.minY)
        capture("11-Prefix-Search")

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "42")
        XCTAssertTrue(app.buttons["search-address-42 Queen Street"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["search-stops-heading"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-stop-'")).firstMatch.exists)
    }

    @MainActor
    func testCombinedSearchCanChooseAddress() {
        let app = launch()
        app.buttons["new-group"].tap()
        let field = app.searchFields["Search address or stop number"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("1063")
        let stop = app.buttons["search-stop-1063"]
        let address = app.buttons["search-address-1063 Great North Road"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        XCTAssertLessThan(stop.frame.minY, address.frame.minY)
        capture("10-Combined-Search")
        address.tap()
        let nearbyStop = app.buttons["select-1063"]
        XCTAssertTrue(nearbyStop.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["picker-next"].isEnabled)
        nearbyStop.tap()
        XCTAssertTrue(app.buttons["picker-next"].isEnabled)
    }

    @MainActor
    func testAddressSearchWithTextAndMixedInput() {
        let app = launch()
        app.buttons["new-group"].tap()
        let field = app.searchFields["Search address or stop number"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Queen Street")
        XCTAssertTrue(app.buttons["search-address-Queen Street"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-stop-'")).firstMatch.exists)

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "10")
        XCTAssertTrue(app.buttons["search-stop-1063"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["search-address-10 Queen Street"].exists)

        field.typeText(" Queen Street")
        XCTAssertTrue(app.buttons["search-address-10 Queen Street"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["search-stop-1063"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-stop-'")).firstMatch.exists)

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 15))
        XCTAssertTrue(app.buttons["select-1063"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-address-'")).firstMatch.exists)
    }

    @MainActor
    func testLargeTextLayout() {
        let app = launch(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        capture("07-Large-Text-Groups")
        app.buttons["group-Office"].tap()
        XCTAssertTrue(app.buttons["departure-preview-0"].waitForExistence(timeout: 5))
        capture("08-Large-Text-Departures")
    }

    @MainActor
    func testMapSelectionAndCancel() {
        let app = launch()
        app.buttons["new-group"].tap()
        let stop = app.buttons["map-stop-7037"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        XCTAssertTrue(stop.isHittable)
        stop.tap()
        XCTAssertTrue(app.staticTexts["Nearby routes: CTY, NX2, 923"].waitForExistence(timeout: 5))
        capture("09-Focused-Stop")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["group-Office"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'group-'")).count, 2)
    }
}

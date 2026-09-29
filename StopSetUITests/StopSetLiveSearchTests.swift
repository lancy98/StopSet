import XCTest

final class StopSetLiveSearchTests: XCTestCase {
    @MainActor
    func testLiveAddressSearchWhileTyping() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STOPSET_LIVE_SEARCH_TESTS"] == "1",
                          "Enable STOPSET_LIVE_SEARCH_TESTS to test real Apple Maps requests.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Live-address-search-final-state"
            attachment.lifetime = .keepAlways
            add(attachment)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Live-address-search-elements"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        let newGroup = app.buttons["new-group"]
        XCTAssertTrue(newGroup.waitForExistence(timeout: 10))
        newGroup.tap()
        let field = app.searchFields["Search address or stop number"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("21")
        let addresses = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-address-'"))
        XCTAssertTrue(app.buttons["search-stop-2100"].waitForExistence(timeout: 20))
        field.typeText(" holl")
        let matchingAddress = addresses.matching(NSPredicate(format: "label CONTAINS[cd] '21 Holl' AND label CONTAINS[cd] 'Auckland'")).firstMatch
        XCTAssertTrue(matchingAddress.waitForExistence(timeout: 20))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Live-21-holl-address-results"
        attachment.lifetime = .keepAlways
        add(attachment)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7) + "Queen Street")
        let street = addresses.matching(NSPredicate(format: "label CONTAINS[cd] 'Queen' AND label CONTAINS[cd] 'Auckland'")).firstMatch
        XCTAssertTrue(street.waitForExistence(timeout: 20))
        street.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'select-'")).firstMatch.waitForExistence(timeout: 20))
    }
}

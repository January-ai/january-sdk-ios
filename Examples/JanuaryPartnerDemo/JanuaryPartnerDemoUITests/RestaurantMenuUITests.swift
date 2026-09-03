import XCTest

@MainActor
final class RestaurantMenuUITests: XCTestCase {
    private let fixtureOrigin = URL(string: "http://127.0.0.1:18768")!
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        try await request("/__reset")
        app = XCUIApplication()
        app.resetAuthorizationStatus(for: .microphone)
        app.launchArguments = [
            "-ui-testing",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXS",
        ]
        app.launch()
    }

    func testLoadsSelectedRestaurantMenuByID() async throws {
        openRestaurant()
        XCTAssertTrue(app.staticTexts["Fixture bowl"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fixture soup"].exists)
        attachScreenshot("restaurant-menu-success")
    }

    func testProductionStyle404FallsBackWithoutShowingAnError() async throws {
        try await control("/v1.2/restaurants/cafe/menu-items", status: 404)
        openRestaurant()
        XCTAssertTrue(app.staticTexts["Fixture bowl"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No matching result was found"].exists)
        attachScreenshot("restaurant-menu-404-fallback")
    }

    func testEmpty404FallbackShowsEmptyState() async throws {
        try await control("/v1.2/restaurants/cafe/menu-items", status: 404)
        try await control("/v1.2/menu-items", empty: true)
        openRestaurant()
        XCTAssertTrue(app.staticTexts["No menu items found"].waitForExistence(timeout: 5))
        attachScreenshot("restaurant-menu-empty")
    }

    func testServerErrorShowsRetryAndRecovers() async throws {
        try await control("/v1.2/restaurants/cafe/menu-items", status: 500)
        openRestaurant()
        XCTAssertTrue(app.staticTexts["January couldn’t complete the request"].waitForExistence(timeout: 5))
        attachScreenshot("restaurant-menu-error")
        try await control("/v1.2/restaurants/cafe/menu-items")
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.staticTexts["Fixture bowl"].waitForExistence(timeout: 5))
    }

    func testFoodSearchDetailsGlucoseAndAlternatives() async throws {
        try await control("/v1.2/foods", status: 500)
        let search = app.textFields["Food name"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("oatmeal")
        tap("Search foods")
        wait("January couldn’t complete the request")

        try await control("/v1.2/foods")
        tap("Try again")
        wait("Fixture oatmeal")
        tap("Fixture oatmeal")
        wait("Food details")

        tap("Check glucose")
        wait("Medium impact")
        tap("Close glucose response")
    }

    func testFoodAlternatives() {
        let search = app.textFields["Food name"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("oatmeal")
        tap("Search foods")
        wait("Fixture oatmeal")
        tap("Fixture oatmeal")
        wait("Food details")
        tap("Find alternatives")
        wait("Food alternatives")
        tap("Find alternatives")
        wait("Fixture lentils")
    }

    func testFoodSearchEmptyStateAndValidationErrors() async throws {
        try await control("/v1.2/foods", empty: true)
        let search = app.textFields["Food name"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("missing")
        tap("Search foods")
        wait("No foods found")

        for (status, title) in [(401, "Couldn’t use the configured credentials"), (422, "Check the information you entered"), (429, "Too many requests")] {
            try await control("/v1.2/foods", status: status)
            tap("Search foods")
            wait(title)
        }
    }

    func testMealDescriptionShowsGlucosePredictionAndResets() {
        let description = app.segmentedControls.buttons["Description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
        description.tap()

        let search = app.textFields["Describe what was eaten"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), app.debugDescription)
        search.tap()
        search.typeText("pizza and pepper")
        tap("Parse meal")
        wait("Meal nutrition")
        tap("Show glucose prediction")
        wait("Medium impact")
        attachScreenshot("meal-description-glucose")

        tap("Analyze another meal")
        XCTAssertFalse(app.staticTexts["Meal nutrition"].exists)
        for _ in 0..<3 {
            app.swipeDown()
        }
        let resetSearch = app.textFields["Describe what was eaten"]
        XCTAssertTrue(resetSearch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(resetSearch.value as? String, "Describe what was eaten")
        attachScreenshot("meal-description-reset")
    }

    func testPhotoScanCorrectionAndRetry() async throws {
        tab("Scan")
        tap("Sample meal")
        try await control("/v1.2/food-analysis/image", status: 500)
        tap("Analyze meal")
        wait("January couldn’t complete the request")
        try await control("/v1.2/food-analysis/image")
        tap("Try again")
        wait("Fixture breakfast")
        tap("Correct result")
        let correction = app.textViews.firstMatch
        XCTAssertTrue(correction.waitForExistence(timeout: 5))
        correction.tap(); correction.typeText("This was lentils")
        try await control("/v1.2/food-analysis/corrections", status: 500)
        tap("Submit correction")
        wait("January couldn’t complete the request")
        XCTAssertEqual(correction.value as? String, "This was lentils")
        try await control("/v1.2/food-analysis/corrections")
        tap("Try again")
        wait("Corrected breakfast")
    }

    func testFoodLogsLoadAndUpdate() async throws {
        try await request("/__seed")
        tab("Food Logs")
        wait("Fixture breakfast")
        tap("Fixture breakfast")
        tap("Edit")
        wait("Edit food log")
        tap("Update food log")
        wait("Food logs")
        wait("Fixture breakfast")
    }

    func testFoodLogDelete() async throws {
        try await request("/__seed")
        tab("Food Logs")
        wait("Fixture breakfast")
        tap("Fixture breakfast")
        tap("Delete food log")
        let destructive = app.buttons
            .matching(NSPredicate(format: "label == %@", "Delete food log"))
            .allElementsBoundByIndex
            .last(where: \.isHittable)
        XCTAssertNotNil(destructive)
        destructive?.tap()
        wait("No food logs in this range")
    }

    func testFoodLogCreateAndRetry() async throws {
        tab("Food Logs")
        wait("No food logs in this range")
        tap("Add food log")
        wait("New food log")
        tap("Add first food")
        addFood()
        try await control("/v1.2/food-logs", status: 500)
        tap("Save food log")
        wait("January couldn’t complete the request")
        try await control("/v1.2/food-logs")
        tap("Try again")
        wait("Fixture breakfast")
    }

    func testGlucoseWorkflowRetainsMealAcrossFailure() async throws {
        tab("Glucose")
        tap("Add food to prediction")
        addFood()
        try await control("/v1.2/glucose/predictions", status: 500)
        tap("Estimate glucose response")
        wait("January couldn’t complete the request")
        try await control("/v1.2/glucose/predictions")
        tap("Try again")
        wait("Estimated response")
    }

    func testAllPrimaryDemoDestinationsAreReachable() {
        XCTAssertTrue(app.tabBars.buttons["Search"].waitForExistence(timeout: 5))
        tab("Scan"); wait("Scan a meal")
        tab("Food Logs"); wait("Food logs")
        tab("Glucose"); wait("Estimate this meal’s response")
        tab("Search"); wait("Search foods")
    }

    func testSearchShowcasesVoiceCapture() {
        let voiceButton = app.buttons["voice-capture-button"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(voiceButton.label, "Use voice input")
        attachScreenshot("search-voice-capture")
    }

    func testVoiceCaptureEntersAndCancelsRecording() {
        addUIInterruptionMonitor(withDescription: "Voice capture permissions") { alert in
            for label in ["Allow", "Continue", "OK"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        let voiceButton = app.buttons["voice-capture-button"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5), app.debugDescription)
        voiceButton.tap()

        for _ in 0..<2 {
            _ = tapSystemPermissionButton(labels: ["Allow", "Continue", "OK"], timeout: 3)
        }

        let stopButton = app.buttons["Stop and transcribe"]
        for _ in 0..<3 where !stopButton.exists {
            app.tap()
            _ = stopButton.waitForExistence(timeout: 2)
        }

        XCTAssertTrue(stopButton.exists, app.debugDescription)
        XCTAssertTrue(app.buttons["Cancel voice input"].exists)
        attachScreenshot("search-voice-recording")

        app.buttons["Cancel voice input"].tap()
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 3), app.debugDescription)
    }

    func testDeniedMicrophonePermissionOffersSettings() {
        addUIInterruptionMonitor(withDescription: "Deny microphone permission") { alert in
            for label in ["Don’t Allow", "Don't Allow"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        let voiceButton = app.buttons["voice-capture-button"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5), app.debugDescription)
        voiceButton.tap()
        if !tapSystemPermissionButton(labels: ["Don’t Allow", "Don't Allow"], timeout: 5) {
            app.tap()
        }

        XCTAssertTrue(app.alerts["Microphone Access Denied"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Please enable microphone access in Settings."].exists)
        XCTAssertTrue(app.alerts.buttons["Settings"].exists)
        XCTAssertTrue(app.alerts.buttons["Cancel"].exists)
        attachScreenshot("search-voice-permission-denied")
    }

    private func tapSystemPermissionButton(labels: [String], timeout: TimeInterval) -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let button = springboard.buttons
            .matching(NSPredicate(format: "label IN %@", labels))
            .firstMatch
        guard button.waitForExistence(timeout: timeout) else { return false }
        button.tap()
        return true
    }

    private func openRestaurant() {
        let restaurants = app.segmentedControls.buttons["Restaurants"]
        XCTAssertTrue(restaurants.waitForExistence(timeout: 5))
        restaurants.tap()
        let search = app.textFields["Restaurant name"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Fixture Cafe")
        app.buttons["Search nearby"].tap()
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Fixture Cafe")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        if app.keyboards.firstMatch.exists {
            app.swipeDown()
        }
        for _ in 0..<5 where !result.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(result.isHittable, "Expected restaurant result to be visible\n\(app.debugDescription)")
        result.tap()
    }

    private func addFood() {
        let search = app.textFields["Search foods"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("oatmeal\n")
        wait("Fixture oatmeal")
        tap("Fixture oatmeal")
        wait("Choose serving")
        tap("Add to meal")
    }

    private func tab(_ label: String) {
        let item = app.tabBars.buttons[label]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
    }

    private func wait(_ label: String) {
        let element = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 12), "Expected \(label)\n\(app.debugDescription)")
    }

    private func tap(_ label: String) {
        let element = reveal(label)
        guard element.isHittable else {
            XCTFail("Expected hittable element \(label)\n\(app.debugDescription)")
            return
        }
        element.tap()
    }

    private func reveal(_ label: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label == %@", label)
        for _ in 0..<8 {
            if let button = app.buttons.matching(predicate).allElementsBoundByIndex.last(where: \.isHittable) {
                return button
            }
            if let text = app.staticTexts.matching(predicate).allElementsBoundByIndex.last(where: \.isHittable) {
                return text
            }
            app.swipeUp()
        }
        return app.buttons.matching(identifier: label).firstMatch
    }

    private func control(_ route: String, status: Int? = nil, empty: Bool = false) async throws {
        var components = URLComponents(url: fixtureOrigin.appending(path: "/__control"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "route", value: route)]
        if let status { components.queryItems?.append(URLQueryItem(name: "status", value: String(status))) }
        if empty { components.queryItems?.append(URLQueryItem(name: "empty", value: "true")) }
        try await request(components.url!)
    }

    private func request(_ path: String) async throws {
        try await request(fixtureOrigin.appending(path: path))
    }

    private func request(_ url: URL) async throws {
        let (_, response) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
final class ClientTokenLiveUITests: XCTestCase {
    func testSearchUsesLocalClientTokenRelay() async throws {
        let relayURL = URL(string: "http://127.0.0.1:8787/january-token")!
        guard let (_, healthResponse) = try? await URLSession.shared.data(
            from: URL(string: "http://127.0.0.1:8787/health")!
        ), (healthResponse as? HTTPURLResponse)?.statusCode == 200 else {
            throw XCTSkip("Start the local January token relay to run this live check.")
        }

        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXS"]
        app.launchEnvironment = [
            "JANUARY_PARTNER_TOKEN_URL": relayURL.absoluteString,
            "JANUARY_PARTNER_SESSION_TOKEN": "local-demo-session",
            "JANUARY_API_KEY": "",
            "JANUARY_END_USER_ID": "ios-live-client-token-uat",
        ]
        app.launch()

        let search = app.textFields["Food name"]
        XCTAssertTrue(search.waitForExistence(timeout: 10), app.debugDescription)
        search.tap()
        search.typeText("pizza")
        app.buttons["Search foods"].tap()

        let results = app.staticTexts["RESULTS · JANUARY FOOD DATABASE"]
        XCTAssertTrue(results.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Couldn’t use the configured credentials"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "live-client-token-search"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

import XCTest

@MainActor
final class RestaurantMenuUITests: XCTestCase {
    private let fixtureOrigin = URL(string: "http://127.0.0.1:18768")!
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        try await request("/__reset")
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
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
        result.tap()
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

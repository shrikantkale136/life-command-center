import XCTest
@testable import LifeCommandCenter

final class GroceryCategoryCatalogTests: XCTestCase {
    func testCustomCategoriesAreTrimmedDeduplicatedAndExcludeBuiltIns() {
        let json = GroceryCategoryCatalog.encode([" Snacks ", "snacks", "Dairy & Eggs", "Baking"])
        XCTAssertEqual(GroceryCategoryCatalog.custom(from: json), ["Snacks", "Baking"])
    }

    func testMalformedCategoryJSONDecodesSafely() {
        XCTAssertEqual(GroceryCategoryCatalog.decoded("not-json"), [])
        XCTAssertEqual(GroceryCategoryCatalog.custom(from: "[]"), [])
    }

    func testOrderingRespectsSavedOrderAndAppendsNewCategoriesBeforeOther() {
        let ordered = GroceryCategoryCatalog.ordered(["Produce", "Snacks", "Other"], by: GroceryCategoryCatalog.encode(["Snacks", "Produce"]))
        XCTAssertEqual(ordered, ["Snacks", "Produce", "Other"])
    }

    func testBuiltInCategoriesIncludeStableOtherSentinel() {
        XCTAssertEqual(GroceryCategoryCatalog.builtIn.last, "Other")
        XCTAssertEqual(GroceryCategoryCatalog.decoded(GroceryCategoryCatalog.encode(["Produce", "Other"])), ["Produce", "Other"])
    }
}

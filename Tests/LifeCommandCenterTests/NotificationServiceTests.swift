import XCTest
import UserNotifications
@testable import LifeCommandCenter

final class NotificationServiceTests: XCTestCase {
    func testPastNotificationsAreNotCreated() {
        XCTAssertNil(NotificationService.makeRequest(id: "past", title: "Task", date: .now.addingTimeInterval(-60)))
    }

    func testFutureNotificationHasExpectedContentAndIdentifier() throws {
        let date = Date.now.addingTimeInterval(3600)
        let request = try XCTUnwrap(NotificationService.makeRequest(id: "task-1", title: "Pay water bill", date: date))
        XCTAssertEqual(request.identifier, "task-1")
        XCTAssertEqual(request.content.title, "Coming up")
        XCTAssertEqual(request.content.body, "Pay water bill is coming up.")
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, Calendar.current.component(.hour, from: date))
        XCTAssertEqual(trigger.dateComponents.day, Calendar.current.component(.day, from: date))
    }

    func testNotificationPersonalizesWithTrimmedPreferredName() throws {
        let request = try XCTUnwrap(NotificationService.makeRequest(id: "id", title: "Clean garage", date: .now.addingTimeInterval(3600), preferredName: "  Shrikant \n"))
        XCTAssertEqual(request.content.title, "Hey Shrikant! 👋")
    }
}

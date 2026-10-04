import XCTest
@testable import LifeCommandCenter

final class RepeatRuleTests: XCTestCase {
    func testNeverHasNoNextOccurrence() {
        XCTAssertNil(RepeatRule.none.next(after: date(2026, 1, 15)))
    }

    func testDailyRecurrence() {
        XCTAssertEqual(dayParts(RepeatRule.daily.next(after: date(2026, 1, 15))), [2026, 1, 16])
    }

    func testWeeklyRecurrence() {
        XCTAssertEqual(dayParts(RepeatRule.weekly.next(after: date(2026, 1, 15))), [2026, 1, 22])
    }

    func testMonthlyRecurrence() {
        XCTAssertEqual(dayParts(RepeatRule.monthly.next(after: date(2026, 1, 15))), [2026, 2, 15])
    }

    func testQuarterlyRecurrence() {
        XCTAssertEqual(dayParts(RepeatRule.quarterly.next(after: date(2026, 1, 15))), [2026, 4, 15])
    }

    func testYearlyRecurrence() {
        XCTAssertEqual(dayParts(RepeatRule.yearly.next(after: date(2026, 1, 15))), [2027, 1, 15])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func dayParts(_ date: Date?) -> [Int]? {
        guard let date else { return nil }
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return [year, month, day]
    }
}

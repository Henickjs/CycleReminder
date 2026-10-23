import XCTest
@testable import CycleReminder

/// 排期算法测试：与 tools/verify_logic.js 中的独立复算一一对应。
final class NotificationManagerTests: XCTestCase {
    private var calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func rule(start: Date, interval: Int, end: Date? = nil) -> ReminderRule {
        ReminderRule(content: "测试", startDate: start, endDate: end, intervalDays: interval)
    }

    func testFutureStartFiresAtStartDate() {
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 10, 28, 9, 0)
        let dates = NotificationManager.upcomingDates(for: rule(start: start, interval: 3), after: now, limit: 2)
        XCTAssertEqual(dates.count, 2)
        XCTAssertEqual(dates[0], start)
        XCTAssertEqual(dates[1], date(2026, 10, 31, 9, 0))
    }

    func testPastStartAdvancesToNextOccurrence() {
        // 开始于 10 天前、周期 3 天 → 下一个提醒点 = start + 12 天（now + 2 天）
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 10, 13, 9, 0)
        let dates = NotificationManager.upcomingDates(for: rule(start: start, interval: 3), after: now, limit: 1)
        XCTAssertEqual(dates.first, date(2026, 10, 25, 9, 0))
    }

    func testDailyReminderFromLongPastStart() {
        // 100 天前开始、每天 → 下一次 = start + 101 天
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 7, 15, 9, 0)
        let dates = NotificationManager.upcomingDates(for: rule(start: start, interval: 1), after: now, limit: 1)
        XCTAssertEqual(dates.first, date(2026, 10, 24, 9, 0))
    }

    func testEndDateClampsOccurrencesInclusive() {
        // start 10/22、周期 3 天、结束 = start + 13 天 → 只有 10/25、10/28、10/31、11/3 四个点
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 10, 22, 9, 0)
        let end = date(2026, 11, 4, 9, 0)
        let dates = NotificationManager.upcomingDates(for: rule(start: start, interval: 3, end: end), after: now, limit: 16)
        let expected = [
            date(2026, 10, 25, 9, 0),
            date(2026, 10, 28, 9, 0),
            date(2026, 10, 31, 9, 0),
            date(2026, 11, 3, 9, 0),
        ]
        XCTAssertEqual(dates, expected)
    }

    func testEndedRuleHasNoOccurrences() {
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 9, 23, 9, 0)
        let end = date(2026, 10, 18, 9, 0)
        let dates = NotificationManager.upcomingDates(for: rule(start: start, interval: 7, end: end), after: now, limit: 16)
        XCTAssertTrue(dates.isEmpty)
    }

    func testIntervalLargerThanRemainingSpan() {
        // 40 天前开始、周期 90 天、30 天后结束：下一个周期点在 50 天后，已越过结束时间
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 9, 13, 9, 0)
        let end = date(2026, 11, 22, 9, 0)
        let dates = NotificationManager.upcomingDates(for: rule(start: start, interval: 90, end: end), after: now, limit: 16)
        XCTAssertTrue(dates.isEmpty)
    }

    func testFireTimeStaysAtSameWallClockTimeAcrossYears() {
        // 跨年规则：所有提醒点都晚于 now，且始终落在 9:00（Calendar 按天进位，时刻不漂移）
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 1, 1, 9, 0)
        let dates = NotificationManager.upcomingDates(
            for: rule(start: start, interval: 90, end: date(2028, 1, 1, 9, 0)),
            after: now,
            limit: 5
        )
        XCTAssertEqual(dates.count, 5)
        XCTAssertTrue(dates.allSatisfy { $0 > now })
        XCTAssertTrue(dates.allSatisfy {
            calendar.component(.hour, from: $0) == 9 && calendar.component(.minute, from: $0) == 0
        })
    }

    func testLimitIsRespected() {
        let now = date(2026, 10, 23, 12, 0)
        let start = date(2026, 10, 24, 9, 0)
        let dates = NotificationManager.upcomingDates(for: rule(start: start, interval: 1), after: now, limit: 16)
        XCTAssertEqual(dates.count, 16)
        XCTAssertEqual(dates.first, start)
        XCTAssertEqual(dates.last, date(2026, 11, 8, 9, 0))
    }
}

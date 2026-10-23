import XCTest
@testable import CycleReminder

/// 登录规则测试：账号 admin，密码为当天 8 位日期。
final class LoginManagerTests: XCTestCase {
    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }

    func testPasswordIsEightDigitDate() {
        XCTAssertEqual(LoginManager.todaysPassword(date: date(2026, 10, 23)), "20261023")
        XCTAssertEqual(LoginManager.todaysPassword(date: date(2026, 1, 5)), "20260105")
    }

    func testLoginSucceedsWithTodaysPassword() {
        let manager = LoginManager()
        XCTAssertTrue(manager.login(user: "admin", password: LoginManager.todaysPassword()))
        XCTAssertTrue(manager.isLoggedIn)
    }

    func testLoginAcceptsCaseInsensitiveAndSurroundingWhitespace() {
        XCTAssertTrue(LoginManager().login(user: " Admin ", password: LoginManager.todaysPassword()))
    }

    func testLoginRejectsWrongPasswordAccountAndYesterday() {
        let manager = LoginManager()
        XCTAssertFalse(manager.login(user: "admin", password: "00000000"))
        XCTAssertFalse(manager.login(user: "root", password: LoginManager.todaysPassword()))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
        XCTAssertFalse(manager.login(user: "admin", password: LoginManager.todaysPassword(date: yesterday)))
        XCTAssertFalse(manager.isLoggedIn)
    }

    func testLogoutClearsState() {
        let manager = LoginManager()
        XCTAssertTrue(manager.login(user: "admin", password: LoginManager.todaysPassword()))
        manager.logout()
        XCTAssertFalse(manager.isLoggedIn)
    }
}

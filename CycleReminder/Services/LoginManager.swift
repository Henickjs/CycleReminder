import Foundation

/// 登录门卫：账号 `admin`，密码为当天日期（8 位，如 2026-10-23 → 20261023）。
/// 每次启动 App 需要重新登录；锁定不影响已注册的提醒通知照常送达。
final class LoginManager: ObservableObject {
    static let shared = LoginManager()
    static let account = "admin"

    @Published private(set) var isLoggedIn = false

    // 固定公历与 yyyyMMdd 格式，不受设备地区 / 日历影响
    private static let passwordFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    func login(user: String, password: String) -> Bool {
        let accountOK = user.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(Self.account) == .orderedSame
        guard accountOK, password == Self.todaysPassword() else { return false }
        isLoggedIn = true
        return true
    }

    func logout() {
        isLoggedIn = false
    }

    static func todaysPassword(date: Date = .now) -> String {
        passwordFormatter.string(from: date)
    }
}

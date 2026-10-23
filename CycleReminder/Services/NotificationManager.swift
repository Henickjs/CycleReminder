import Foundation
import UserNotifications

/// 本地通知的调度中枢：以当前规则为准全量重建通知计划。
enum NotificationManager {
    private static let identifierPrefix = "cycle-reminder-"
    /// 每条规则最多预先排入的提醒次数
    private static let maxOccurrencesPerRule = 16
    /// iOS 每个应用最多 64 条挂起通知，留出余量
    private static let totalBudget = 60

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 从 `rule.startDate` 起按周期递推，返回 `now` 之后、且不晚于结束时间的 `limit` 个提醒时间。
    /// 用 Calendar 按天进位，跨夏令时仍保持同一本地时刻。
    static func upcomingDates(for rule: ReminderRule, after now: Date = .now, limit: Int = 1) -> [Date] {
        let interval = max(1, rule.intervalDays)
        let calendar = Calendar.current
        let period = TimeInterval(interval) * 86400

        var date = rule.startDate
        if date <= now {
            let steps = max(1, Int(ceil((now.timeIntervalSince(date) + 1) / period)))
            date = calendar.date(byAdding: .day, value: interval * steps, to: date) ?? now
        }
        while date <= now, let next = calendar.date(byAdding: .day, value: interval, to: date) {
            date = next
        }

        var dates: [Date] = []
        var current = date
        while dates.count < limit {
            // 结束时间之后不再提醒（跨度几天、几个月、几年都由它决定）
            if let endDate = rule.endDate, current > endDate { break }
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: interval, to: current) else { break }
            current = next
        }
        return dates
    }

    /// 先清掉本应用所有旧计划，再按启用的规则重新注册。
    /// 每条规则预先排入未来若干次（App 回到前台时会自动续排），保证时间点精确。
    static func syncAll(_ rules: [ReminderRule]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let staleIdentifiers = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: staleIdentifiers)

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let enabledRules = rules.filter { $0.isEnabled && $0.intervalDays >= 1 }
        guard !enabledRules.isEmpty else { return }

        // 按规则数量均摊通知预算，避免前面的规则占满 64 条上限
        let occurrencesPerRule = min(maxOccurrencesPerRule, max(2, totalBudget / enabledRules.count))

        var budget = totalBudget
        for rule in enabledRules {
            let option = SoundCatalog.option(for: rule.soundID)
            let fireDates = upcomingDates(for: rule, limit: occurrencesPerRule)

            for (index, fireDate) in fireDates.enumerated() {
                let interval = fireDate.timeIntervalSinceNow
                guard interval > 1, budget > 0 else { continue }

                let content = UNMutableNotificationContent()
                content.title = "周期提醒"
                content.body = rule.content.isEmpty ? "你设置了一条提醒" : rule.content
                content.sound = option.fileName.map {
                    UNNotificationSound(named: UNNotificationSoundName(rawValue: $0))
                } ?? .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(identifierPrefix)\(rule.id.uuidString)-\(index)",
                    content: content,
                    trigger: trigger
                )
                do {
                    try await center.add(request)
                    budget -= 1
                } catch {
                    continue
                }
            }
        }
    }
}

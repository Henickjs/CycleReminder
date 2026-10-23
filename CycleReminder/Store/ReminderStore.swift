import Foundation
import UserNotifications

/// 规则的内存态 + JSON 文件持久化，并在任何变更后重建本地通知。
final class ReminderStore: ObservableObject {
    static let shared = ReminderStore()

    @Published private(set) var rules: [ReminderRule] = []
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("ReminderRules.json")

        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601

        load()
        refreshAuthorizationStatus()
    }

    // MARK: - 增删改

    /// 新增规则插入到最前；编辑则原地更新。
    func upsert(_ rule: ReminderRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.insert(rule, at: 0)
        }
        persistAndSync()
    }

    /// 暂停 / 恢复某条规则（取消提醒但保留规则）。
    func setEnabled(_ enabled: Bool, for rule: ReminderRule) {
        guard var updated = rules.first(where: { $0.id == rule.id }) else { return }
        updated.isEnabled = enabled
        upsert(updated)
    }

    /// 删除规则，同时移除它已注册的全部通知。
    func delete(_ rule: ReminderRule) {
        rules.removeAll { $0.id == rule.id }
        persistAndSync()
    }

    // MARK: - 通知

    func resyncNotifications() {
        let snapshot = rules
        Task { await NotificationManager.syncAll(snapshot) }
    }

    func refreshAuthorizationStatus() {
        Task { authorizationStatus = await NotificationManager.authorizationStatus() }
    }

    func requestAuthorizationThenSync() async {
        _ = await NotificationManager.requestAuthorization()
        authorizationStatus = await NotificationManager.authorizationStatus()
        resyncNotifications()
    }

    // MARK: - 持久化

    private func persistAndSync() {
        save()
        resyncNotifications()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([ReminderRule].self, from: data) else { return }
        rules = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(rules) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

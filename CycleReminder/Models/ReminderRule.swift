import Foundation

/// 一条周期提醒规则：从 `startDate` 开始，每隔 `intervalDays` 天提醒一次，
/// 到 `endDate` 自动停止（nil 表示一直提醒）。跨度几天、几个月、几年都可以。
struct ReminderRule: Identifiable, Codable, Hashable {
    var id: UUID
    var content: String
    var startDate: Date
    var endDate: Date?
    var intervalDays: Int
    var soundID: String
    var isEnabled: Bool
    var createdAt: Date

    init(id: UUID = UUID(),
         content: String,
         startDate: Date,
         endDate: Date? = nil,
         intervalDays: Int,
         soundID: String = SoundCatalog.defaultSound.id,
         isEnabled: Bool = true,
         createdAt: Date = .now) {
        self.id = id
        self.content = content
        self.startDate = startDate
        self.endDate = endDate
        self.intervalDays = intervalDays
        self.soundID = soundID
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var intervalText: String {
        intervalDays <= 1 ? "每天" : "每 \(intervalDays) 天"
    }
}

import SwiftUI
import UIKit

struct RuleEditView: View {
    @EnvironmentObject private var store: ReminderStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var soundPlayer = SoundPlayer()

    private let existingRule: ReminderRule?

    @State private var content: String
    @State private var startDate: Date
    @State private var intervalDays: Int
    @State private var soundID: String
    @State private var isEnabled: Bool
    @State private var preset: IntervalPreset
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var showsPermissionAlert = false

    private enum IntervalPreset: Hashable {
        case daily
        case everyThreeDays
        case weekly
        case monthly
        case custom

        init(_ days: Int) {
            switch days {
            case 1: self = .daily
            case 3: self = .everyThreeDays
            case 7: self = .weekly
            case 30: self = .monthly
            default: self = .custom
            }
        }

        var days: Int? {
            switch self {
            case .daily: 1
            case .everyThreeDays: 3
            case .weekly: 7
            case .monthly: 30
            case .custom: nil
            }
        }
    }

    init(rule: ReminderRule?) {
        existingRule = rule
        _content = State(initialValue: rule?.content ?? "")
        let initialStart = rule?.startDate ?? Self.nextWholeHour()
        _startDate = State(initialValue: initialStart)
        _hasEndDate = State(initialValue: rule?.endDate != nil)
        _endDate = State(initialValue: rule?.endDate
            ?? Calendar.current.date(byAdding: .day, value: 7, to: max(initialStart, .now))
            ?? initialStart)
        let interval = rule?.intervalDays ?? 1
        _intervalDays = State(initialValue: interval)
        _preset = State(initialValue: IntervalPreset(interval))
        _soundID = State(initialValue: rule?.soundID ?? SoundCatalog.defaultSound.id)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                contentSection
                scheduleSection
                soundSection
                statusSection
            }
            .onChange(of: preset) { newValue in
                if let days = newValue.days { intervalDays = days }
            }
            .onChange(of: hasEndDate) { on in
                // 打开结束时间开关时给一个合理的默认值（开始时间一周后）
                if on, endDate <= startDate {
                    endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
                }
            }
            .onChange(of: startDate) { newStart in
                if endDate < newStart { endDate = newStart }
            }
            .navigationTitle(existingRule == nil ? "新建提醒" : "编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(trimmedContent.isEmpty)
                }
            }
            .alert("通知已被关闭", isPresented: $showsPermissionAlert) {
                Button("去设置") { openSettings(); dismiss() }
                Button("知道了", role: .cancel) { dismiss() }
            } message: {
                Text("请在系统设置中允许「周期提醒」发送通知，否则到点不会提醒。这条规则已保存，开启通知后会自动生效。")
            }
        }
    }

    // MARK: - Sections

    private var contentSection: some View {
        Section {
            TextField("例如：记得喝水", text: $content, axis: .vertical)
                .lineLimit(1...4)
        } header: {
            Text("提醒内容")
        }
    }

    private var scheduleSection: some View {
        Section {
            DatePicker("首次提醒", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
            Picker("重复周期", selection: $preset) {
                Text("每天").tag(IntervalPreset.daily)
                Text("3 天").tag(IntervalPreset.everyThreeDays)
                Text("7 天").tag(IntervalPreset.weekly)
                Text("30 天").tag(IntervalPreset.monthly)
                Text("自定义").tag(IntervalPreset.custom)
            }
            .pickerStyle(.segmented)
            if preset == .custom {
                Stepper(value: $intervalDays, in: 1...365) {
                    Text("每 \(intervalDays) 天提醒一次")
                }
            }
            Toggle("设置结束时间", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("结束时间",
                           selection: $endDate,
                           in: startDate...,
                           displayedComponents: [.date, .hourAndMinute])
            }
            LabeledContent("下次提醒", value: nextFireDescription)
        } header: {
            Text("时间")
        } footer: {
            Text("从首次提醒时间开始，每隔一个周期提醒一次；起始时间已过会自动顺延到下一个周期。可选设置结束时间，到期后自动停止。")
        }
    }

    private var soundSection: some View {
        Section {
            ForEach(SoundCatalog.all) { option in
                HStack {
                    Text(option.displayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if soundID == option.id {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    if option.fileName != nil {
                        Button {
                            soundPlayer.preview(option)
                        } label: {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("试听 \(option.displayName)")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { soundID = option.id }
            }
        } header: {
            Text("提示铃声")
        } footer: {
            Text("点按名称选择铃声，点按 ▶ 试听。")
        }
    }

    private var statusSection: some View {
        Section {
            Toggle("启用这条规则", isOn: $isEnabled)
        } footer: {
            Text("关闭后保留规则但不再提醒，可随时重新开启。")
        }
    }

    // MARK: - 保存

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftRule: ReminderRule {
        ReminderRule(
            id: existingRule?.id ?? UUID(),
            content: trimmedContent,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            intervalDays: max(1, intervalDays),
            soundID: soundID,
            isEnabled: isEnabled,
            createdAt: existingRule?.createdAt ?? .now
        )
    }

    private var nextFireDescription: String {
        if let next = NotificationManager.upcomingDates(for: draftRule).first {
            return next.formatted(date: .abbreviated, time: .shortened)
        }
        return draftRule.endDate == nil ? "—" : "无（超出结束时间）"
    }

    private func save() async {
        guard !trimmedContent.isEmpty else { return }
        if store.authorizationStatus == .notDetermined {
            await store.requestAuthorizationThenSync()
        }
        store.upsert(draftRule)
        if store.authorizationStatus == .denied {
            showsPermissionAlert = true
        } else {
            dismiss()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private static func nextWholeHour() -> Date {
        let calendar = Calendar.current
        let next = Date.now.addingTimeInterval(3600)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: next)
        return calendar.date(from: components) ?? next
    }
}

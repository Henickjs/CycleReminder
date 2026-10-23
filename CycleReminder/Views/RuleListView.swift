import SwiftUI
import UIKit

struct RuleListView: View {
    @EnvironmentObject private var store: ReminderStore
    @State private var showsNewRuleSheet = false
    @State private var editingRule: ReminderRule?

    var body: some View {
        NavigationStack {
            Group {
                if store.rules.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("暂无提醒")
                            .font(.headline)
                        Text("设置起始时间和周期，到点自动提醒你")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("新建提醒") { showsNewRuleSheet = true }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ruleList
                }
            }
            .navigationTitle("提醒")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        LoginManager.shared.logout()
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                    .accessibilityLabel("锁定")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showsNewRuleSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增提醒")
                }
            }
            .sheet(isPresented: $showsNewRuleSheet) {
                RuleEditView(rule: nil)
            }
            .sheet(item: $editingRule) { rule in
                RuleEditView(rule: rule)
            }
        }
    }

    private var ruleList: some View {
        List {
            if store.authorizationStatus == .denied {
                permissionBanner
            }
            ForEach(store.rules) { rule in
                RuleCardView(rule: rule)
                    .contentShape(Rectangle())
                    .onTapGesture { editingRule = rule }
                    .accessibilityAddTraits(.isButton)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.delete(rule)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            store.setEnabled(!rule.isEnabled, for: rule)
                        } label: {
                            Label(rule.isEnabled ? "暂停" : "恢复",
                                  systemImage: rule.isEnabled ? "pause.circle" : "play.circle")
                        }
                        .tint(.orange)
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// 通知权限被关时的顶部提示
    private var permissionBanner: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "bell.slash.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("通知已被关闭")
                        .font(.subheadline.weight(.medium))
                    Text("开启通知后才能收到提醒")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct RuleCardView: View {
    let rule: ReminderRule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(rule.content.isEmpty ? "未命名提醒" : rule.content)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { ReminderStore.shared.setEnabled($0, for: rule) }
                ))
                .labelsHidden()
            }
            HStack(spacing: 14) {
                Label(rule.intervalText, systemImage: "arrow.triangle.2.circlepath")
                Label(SoundCatalog.option(for: rule.soundID).displayName, systemImage: "bell")
                Spacer(minLength: 0)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            nextLine
        }
        .padding(.vertical, 6)
        .opacity(rule.isEnabled ? 1 : 0.45)
    }

    /// 第三行：下次提醒时间；设置了结束时间的附带显示“至 …”，已到期的显示“已结束”
    @ViewBuilder
    private var nextLine: some View {
        let next = NotificationManager.upcomingDates(for: rule).first
        HStack {
            if let next {
                Label(nextDescription(next), systemImage: "clock.arrow.circlepath")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 0)
                if let end = rule.endDate {
                    Text("至 " + end.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let end = rule.endDate {
                Group {
                    if end < .now {
                        Label("已于 \(end.formatted(date: .abbreviated, time: .shortened)) 结束",
                              systemImage: "flag.checkered")
                    } else {
                        // 结束时间还没到，但下一个周期点已超过它：这条规则期间内不会有提醒
                        Label("至 \(end.formatted(date: .abbreviated, time: .shortened))，期间无提醒",
                              systemImage: "calendar.badge.exclamationmark")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func nextDescription(_ date: Date) -> String {
        let absolute = date.formatted(date: .abbreviated, time: .shortened)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: date, relativeTo: .now)
        return "下次提醒 \(absolute)（\(relative)）"
    }
}

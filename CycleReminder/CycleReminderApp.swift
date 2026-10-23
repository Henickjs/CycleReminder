import SwiftUI

@main
struct CycleReminderApp: App {
    @StateObject private var store = ReminderStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            // 每次回到前台：刷新权限状态，并把本地通知按最新规则重排续期
            store.refreshAuthorizationStatus()
            store.resyncNotifications()
        }
    }
}

/// 根视图：未登录显示登录页，登录后进入主界面。
struct RootView: View {
    @StateObject private var loginManager = LoginManager.shared

    var body: some View {
        ZStack {
            if loginManager.isLoggedIn {
                RuleListView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: loginManager.isLoggedIn)
    }
}

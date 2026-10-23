import SwiftUI

struct LoginView: View {
    private let loginManager = LoginManager.shared

    @State private var account = LoginManager.account
    @State private var password = ""
    @State private var showsError = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case account
        case password
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            VStack(spacing: 14) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.176, green: 0.831, blue: 0.749),
                                Color(red: 0.310, green: 0.275, blue: 0.898),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 22)
                    )
                Text("周期提醒")
                    .font(.title2.bold())
                Text("请登录后使用")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                TextField("账号", text: $account)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .account)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                SecureField("密码", text: $password)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .password)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Button(action: attemptLogin) {
                    Text("登 录")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
                .padding(.top, 8)
            }
            .padding(.top, 44)

            if showsError {
                Text("账号或密码不正确")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.top, 12)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear { focusedField = .password }
    }

    private func attemptLogin() {
        showsError = false
        if loginManager.login(user: account, password: password) {
            // RootView 监听 isLoggedIn，自动切换到主界面
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { showsError = true }
            password = ""
            focusedField = .password
        }
    }
}

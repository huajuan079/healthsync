import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel

    init(container: AppContainer) {
        self._viewModel = StateObject(wrappedValue: LoginViewModel(loginUseCase: container.loginUseCase))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.background, Color.secondaryBackground], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill").font(.system(size: 60)).foregroundColor(Color.appAccent)
                    Text("小炎健康助手").font(.title).fontWeight(.bold).foregroundColor(.text)
                    Text("安全同步您的健康数据").font(.subheadline).foregroundColor(.secondaryText)
                }
                Spacer()
                LoginFormView(viewModel: viewModel)
                Spacer()
                Text("v1.0.0").font(.caption).foregroundColor(.tertiaryText)
            }.padding()

            if let message = viewModel.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.white)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)).animation(.easeOut(duration: 0.25)),
                        removal: .opacity.animation(.easeIn(duration: 0.2))
                    )
                )
            }
        }
        .task { viewModel.warmUpConnection() }
        .onChange(of: viewModel.errorMessage) { msg in
            guard msg != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { viewModel.errorMessage = nil }
            }
        }
    }
}

struct LoginFormView: View {
    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("用户名").font(.subheadline).foregroundColor(.secondaryText)
                HStack {
                    Image(systemName: "person").foregroundColor(.tertiaryText).frame(width: 20)
                    TextField("输入用户名", text: $viewModel.username).textInputAutocapitalization(.never).foregroundColor(.text)
                }.padding().background(Color.tertiaryBackground).cornerRadius(10)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("密码").font(.subheadline).foregroundColor(.secondaryText)
                HStack {
                    Image(systemName: "lock").foregroundColor(.tertiaryText).frame(width: 20)
                    SecureField("输入密码", text: $viewModel.password).foregroundColor(.text)
                }.padding().background(Color.tertiaryBackground).cornerRadius(10)
            }
            Button(action: { viewModel.login() }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("登录").font(.headline).foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isFormValid ? Color.appAccent : Color.tertiaryText)
                .cornerRadius(10)
            }
            .disabled(!viewModel.isFormValid)
        }
    }
}

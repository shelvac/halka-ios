import SwiftUI

@main
struct HalkaApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

/// Top-level router: splash → login/register → (premium) → app.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch model.screen {
            case .splash:
                SplashView().transition(.opacity)
            case .login:
                LoginView().transition(.opacity)
            case .register:
                RegisterView().transition(.opacity)
            case .verifyEmail:
                VerifyEmailView().transition(.opacity)
            case .forgot:
                ForgotPasswordView().transition(.opacity)
            case .newPassword:
                NewPasswordView().transition(.opacity)
            case .premium:
                PaywallView().transition(.opacity)
            case .app:
                if model.role == .dietitian {
                    DietitianPanelView().transition(.opacity)
                } else {
                    MainTabView().transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .preferredColorScheme(.light)
        // Saatte antrenman bitirip uygulamaya dönünce veri taze olsun:
        // Health yalnızca açılışta okunuyordu, arka planda kalınca bayatlıyordu.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, model.screen == .app else { return }
            Task { await model.refreshFromHealthKit() }
        }
        .onOpenURL { url in model.handleDeepLink(url) }
    }
}

/// The user app: content + custom floating tab bar.
struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        return ZStack(alignment: .bottom) {
            Color.bgApp.ignoresSafeArea()

            Group {
                switch model.tab {
                case .home: HomeView()
                case .coach: CoachView()
                case .meal: MealsView()
                case .workout: WorkoutRootView()
                case .health: HealthView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar()
        }
        .task { await model.refreshFromHealthKit() }
        // US-026: profili eksik kullanıcı önce karşılama akışını görür.
        .fullScreenCover(isPresented: $model.showOnboarding) {
            OnboardingView()
                .environment(model)
        }
    }
}

struct FloatingTabBar: View {
    @Environment(AppModel.self) private var model

    private let items: [(Tab, String, String)] = [
        (.home, "circle.circle", "Özet"),
        (.coach, "message", "AI Koç"),
        (.meal, "fork.knife", "Yemek"),
        (.workout, "dumbbell", "Egzersiz"),
        (.health, "heart", "Sağlık")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                let active = model.tab == item.0
                Button {
                    model.tab = item.0
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.1)
                            .font(.system(size: 19, weight: .semibold))
                        Text(item.2)
                            .font(.h(9.5))
                    }
                    .foregroundStyle(active ? Color.coral : Color.disabledText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.white.opacity(0.94))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.ink.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}

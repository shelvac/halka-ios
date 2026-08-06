import SwiftUI
import Supabase
import AuthenticationServices

// MARK: - Splash

struct SplashView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgApp, .bgSplashBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                RingStack(fractions: [0.75, 0.7, 0.7, 0.7],
                          size: 96, thickness: 7)
                VStack(spacing: 4) {
                    Text("halka")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(Color.ink)
                        .kerning(-1)
                    Text("Her gün %1 daha iyi")
                        .font(.h(13, .bold))
                        .foregroundStyle(Color.sub)
                }
            }
            VStack {
                Spacer()
                Text("Devam etmek için dokun")
                    .font(.h(11, .bold))
                    .foregroundStyle(Color.faint)
                    .padding(.bottom, 70)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.screen = .login }
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            await model.finishSplash()
        }
    }
}

// MARK: - Shared auth field

struct AuthField: View {
    var placeholder: String
    @Binding var text: String
    var secure = false

    var body: some View {
        Group {
            if secure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(.h(14, .semibold))
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Login

struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""
    @State private var password = ""
    @State private var appleNonce: String? = nil

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // mini logo
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.76)
                        .stroke(Color.coral, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 38, height: 38)
                    Circle().fill(Color.coral).frame(width: 16, height: 16)
                }
                .frame(width: 52, height: 52)
                .padding(.bottom, 18)

                Text("Tekrar hoş geldin")
                    .font(.h(27))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.6)
                Text("Halkaların seni bekliyor.")
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.sub)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                VStack(spacing: 10) {
                    AuthField(placeholder: "E-posta", text: $email)
                    AuthField(placeholder: "Şifre", text: $password, secure: true)
                }

                Button {
                    model.forgotSent = false
                    model.authError = nil
                    model.screen = .forgot
                } label: {
                    Text("Şifremi unuttum")
                        .font(.h(12))
                        .foregroundStyle(Color.coralDark)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 10)
                .padding(.bottom, 18)

                if let info = model.authInfo {
                    AuthBanner(text: info, isError: false)
                        .padding(.bottom, 10)
                }
                if let error = model.authError {
                    AuthBanner(text: error, isError: true)
                        .padding(.bottom, 10)
                }

                Button {
                    Task { await model.signIn(email: email, password: password) }
                } label: {
                    if model.authBusy {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Giriş Yap").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .coralButton()
                .disabled(model.authBusy)

                HStack(spacing: 10) {
                    Rectangle().fill(Color.dashBorder).frame(height: 1)
                    Text("veya").font(.h(11, .bold)).foregroundStyle(Color.faint)
                    Rectangle().fill(Color.dashBorder).frame(height: 1)
                }
                .padding(.vertical, 16)

                // US-015 — Native Sign in with Apple (tarayıcı açmaz).
                // Google sunulduğu için App Store Guideline 4.8 gereği zorunlu.
                SignInWithAppleButton(.continue) { request in
                    let nonce = AppleNonce.random()
                    appleNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleNonce.sha256(nonce)
                } onCompletion: { result in
                    model.handleAppleSignIn(result, nonce: appleNonce)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(model.authBusy)

                Button {
                    Task { await model.signInWithProvider(.google) }
                } label: {
                    HStack(spacing: 8) {
                        Image("GoogleLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("Google ile devam et").font(.h(13))
                    }
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.dashBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.authBusy)
                .padding(.top, 10)

                HStack(spacing: 4) {
                    Text("Hesabın yok mu?")
                        .font(.h(12.5, .semibold))
                        .foregroundStyle(Color.sub)
                    Button { model.screen = .register } label: {
                        Text("Kayıt ol")
                            .font(.h(12.5))
                            .foregroundStyle(Color.coralDark)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
            }
            .padding(.horizontal, 28)
        }
    }

}

// MARK: - Register

struct RegisterView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var kvkkAccepted = false
    @State private var showLegal = false

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Hesap oluştur")
                    .font(.h(27))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.6)
                Text("Tartı, tahlil ve halkaların tek yerde.")
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.sub)
                    .padding(.top, 4)
                    .padding(.bottom, 22)

                VStack(spacing: 10) {
                    AuthField(placeholder: "Ad Soyad", text: $name)
                    AuthField(placeholder: "E-posta", text: $email)
                    AuthField(placeholder: "Şifre", text: $password, secure: true)
                }

                HStack(alignment: .top, spacing: 9) {
                    Button { kvkkAccepted.toggle() } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(kvkkAccepted ? Color.green : Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(kvkkAccepted ? Color.green : Color.dashBorder, lineWidth: 2)
                            )
                            .overlay {
                                if kvkkAccepted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sağlık verilerimin uygulama içinde işlenmesine ilişkin")
                            .font(.h(11, .semibold))
                            .foregroundStyle(Color.sub)
                        HStack(spacing: 4) {
                            Button { showLegal = true } label: {
                                Text("KVKK aydınlatma metnini")
                                    .font(.h(11))
                                    .foregroundStyle(Color.coralDark)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            Text("okudum, onaylıyorum.")
                                .font(.h(11, .semibold))
                                .foregroundStyle(Color.sub)
                        }
                    }
                    .lineSpacing(3)
                }
                .padding(.top, 14)
                .padding(.bottom, 18)

                if let error = model.authError {
                    AuthBanner(text: error, isError: true)
                        .padding(.bottom, 10)
                }

                Button {
                    Task { await model.signUp(name: name, email: email, password: password) }
                } label: {
                    if model.authBusy {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Kayıt Ol").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .coralButton()
                .opacity(kvkkAccepted ? 1 : 0.5)
                .disabled(!kvkkAccepted || model.authBusy)

                HStack(spacing: 4) {
                    Text("Zaten hesabın var mı?")
                        .font(.h(12.5, .semibold))
                        .foregroundStyle(Color.sub)
                    Button { model.screen = .login } label: {
                        Text("Giriş yap")
                            .font(.h(12.5))
                            .foregroundStyle(Color.coralDark)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
            }
            .padding(.horizontal, 28)
        }
        .sheet(isPresented: $showLegal) { LegalSheet() }
    }
}

// MARK: - Premium paywall (dietitian)

struct PaywallView: View {
    @Environment(AppModel.self) private var model

    private let features = [
        "Sınırsız danışan ekleme",
        "Danışanların öğün, kilo ve halka takibi",
        "Tahlil + akıllı tartı raporlarına erişim",
        "Haftalık ilerleme raporları"
    ]

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PREMIUM")
                        .font(.h(11))
                        .foregroundStyle(Color.gold)
                        .kerning(2)
                    Text("Diyetisyen paneliyle danışanlarını takip et")
                        .font(.h(26))
                        .foregroundStyle(.white)
                        .kerning(-0.6)
                        .lineSpacing(3)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 10) {
                                CheckBadge(size: 20)
                                Text(feature)
                                    .font(.h(13, .bold))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(.vertical, 22)

                    // Yearly
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Yıllık").font(.h(14)).foregroundStyle(.white)
                            Text("2 ay hediye · %33 indirim")
                                .font(.h(10.5, .bold))
                                .foregroundStyle(Color.gold)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("₺1.190").font(.h(17)).foregroundStyle(.white)
                            Text("₺99 / ay")
                                .font(.h(10, .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.gold, lineWidth: 2)
                    )

                    // Monthly
                    HStack {
                        Text("Aylık").font(.h(14)).foregroundStyle(.white)
                        Spacer()
                        Text("₺149").font(.h(17)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 10)

                    Button { model.startPremium() } label: {
                        Text("Premium'u Başlat")
                            .font(.h(14))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)

                    Button { model.continueFree() } label: {
                        Text("Ücretsiz sürümle devam et")
                            .font(.h(12))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }
                .padding(.horizontal, 26)
                .padding(.top, 70)
                .padding(.bottom, 40)
            }
        }
    }
}


// MARK: - Shared auth banner

struct AuthBanner: View {
    var text: String
    var isError: Bool
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isError ? Color.coralDark : Color.greenDark)
            Text(text)
                .font(.h(12, .semibold))
                .foregroundStyle(isError ? Color.coralDark : Color.greenDark)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isError ? Color.coralBg : Color.greenBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Şifremi Unuttum (US-013)

struct ForgotPasswordView: View {
    @Environment(AppModel.self) private var model
    @State private var email = ""

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    model.authError = nil
                    model.screen = .login
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("Girişe dön").font(.h(13))
                    }
                    .foregroundStyle(Color.coral)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 26)

                Text("Şifreni sıfırla")
                    .font(.h(27))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.6)
                Text("E-posta adresini gir — sıfırlama bağlantısını gönderelim.")
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.sub)
                    .padding(.top, 4)
                    .padding(.bottom, 22)

                if model.forgotSent {
                    // Jenerik onay: adresin kayıtlı olup olmadığı sızdırılmaz
                    // (user enumeration koruması).
                    AuthBanner(
                        text: "Bu adres sistemimizde kayıtlıysa şifre sıfırlama bağlantısı gönderildi. Gelen kutunu ve spam klasörünü kontrol et.",
                        isError: false)

                    Button {
                        model.forgotSent = false
                        model.screen = .login
                    } label: {
                        Text("Girişe dön").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .coralButton()
                    .padding(.top, 18)
                } else {
                    AuthField(placeholder: "E-posta", text: $email)

                    if let error = model.authError {
                        AuthBanner(text: error, isError: true)
                            .padding(.top, 10)
                    }

                    Button {
                        Task { await model.sendPasswordReset(email: email) }
                    } label: {
                        if model.authBusy {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        } else {
                            Text("Sıfırlama Bağlantısı Gönder").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.plain)
                    .coralButton()
                    .disabled(model.authBusy)
                    .padding(.top, 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - E-posta doğrulama bekleme ekranı (US-011 / US-017)

struct VerifyEmailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.coralBg)
                    .frame(width: 76, height: 76)
                    .overlay(
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Color.coral)
                    )
                    .padding(.bottom, 20)

                Text("E-postanı doğrula")
                    .font(.h(24))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.5)

                Text(model.pendingEmail)
                    .font(.h(13))
                    .foregroundStyle(Color.coralDark)
                    .padding(.top, 6)

                Text("adresine bir doğrulama bağlantısı gönderdik. Bağlantıya dokununca uygulama açılacak ve hesabın hazır olacak.")
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.sub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)

                if let info = model.authInfo {
                    AuthBanner(text: info, isError: false).padding(.top, 18)
                }
                if let error = model.authError {
                    AuthBanner(text: error, isError: true).padding(.top, 18)
                }

                Button {
                    Task { await model.resendVerification() }
                } label: {
                    if model.authBusy {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("E-postayı tekrar gönder").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .coralButton()
                .disabled(model.authBusy)
                .padding(.top, 24)

                Button {
                    model.authError = nil
                    model.authInfo = nil
                    model.screen = .login
                } label: {
                    Text("Girişe dön")
                        .font(.h(12.5))
                        .foregroundStyle(Color.sub)
                        .padding(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                Text("E-posta gelmediyse spam klasörünü kontrol et.")
                    .font(.h(11, .semibold))
                    .foregroundStyle(Color.faint)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Yeni şifre belirleme (US-013, deep link ile açılır)

struct NewPasswordView: View {
    @Environment(AppModel.self) private var model
    @State private var password = ""
    @State private var confirm = ""

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Yeni şifreni belirle")
                    .font(.h(27))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.6)
                Text("En az 8 karakter kullan.")
                    .font(.h(13, .semibold))
                    .foregroundStyle(Color.sub)
                    .padding(.top, 4)
                    .padding(.bottom, 22)

                VStack(spacing: 10) {
                    AuthField(placeholder: "Yeni şifre", text: $password, secure: true)
                    AuthField(placeholder: "Yeni şifre (tekrar)", text: $confirm, secure: true)
                }

                if let error = model.authError {
                    AuthBanner(text: error, isError: true).padding(.top, 12)
                }

                Button {
                    Task { await model.setNewPassword(password, confirm: confirm) }
                } label: {
                    if model.authBusy {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else {
                        Text("Şifreyi Güncelle").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .coralButton()
                .disabled(model.authBusy)
                .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
        }
    }
}

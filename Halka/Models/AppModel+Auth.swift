import Foundation
import Supabase
import AuthenticationServices

// MARK: - Gerçek kimlik akışları (Sprint 1: US-010…US-018)
// Supabase yapılandırılmamışsa (anon key boş) her akış demo davranışına düşer;
// uygulama backend'siz de çalışmaya devam eder.

extension AppModel {

    var supabaseReady: Bool { SupabaseService.shared.isConfigured }

    /// US-010 — Splash: geçerli **ve doğrulanmış** oturum varsa doğrudan ana ekrana.
    func finishSplash() async {
        guard screen == .splash else { return }
        if supabaseReady, await SupabaseService.shared.hasValidSession() {
            if await SupabaseService.shared.isEmailVerified() {
                await enterApp()
                return
            }
            // Doğrulanmamış hesap: içeri alma, doğrulama ekranına yönlendir.
            pendingEmail = await SupabaseService.shared.currentEmail() ?? ""
            screen = .verifyEmail
            return
        }
        screen = .login
    }

    /// Oturum hazır — profil bilgisini yükleyip uygulamayı aç.
    func enterApp() async {
        await loadProfile()
        role = .user
        screen = .app
    }

    /// US-012 — E-posta ile giriş (doğrulama kontrollü).
    func signIn(email: String, password: String) async {
        authError = nil
        authInfo = nil
        guard supabaseReady else { login(); return }   // demo modu
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty, !password.isEmpty else {
            authError = "E-posta ve şifreni gir."
            return
        }
        authBusy = true
        defer { authBusy = false }
        do {
            try await SupabaseService.shared.signIn(email: email, password: password)
            guard await SupabaseService.shared.isEmailVerified() else {
                pendingEmail = email
                await SupabaseService.shared.signOut()
                screen = .verifyEmail
                return
            }
            if loginRole == .dietitian {
                await loadProfile()
                screen = .premium
            } else {
                await enterApp()
            }
        } catch {
            authError = await Self.signInMessage(error, email: email)
        }
    }

    /// Giriş hatasını ayrıştırır: Supabase güvenlik gereği "yanlış şifre" ile
    /// "hesap yok"u aynı mesajla döndürür; ürün kararı olarak bunları ayırıyoruz.
    static func signInMessage(_ error: Error, email: String) async -> String {
        let text = error.localizedDescription.lowercased()
        guard text.contains("invalid login credentials") else {
            return authMessage(error)
        }
        if let status = await SupabaseService.shared.accountStatus(email: email) {
            if !status.exists {
                return "Bu e-posta adresiyle kayıtlı bir hesap bulunamadı."
            }
            if status.isOAuthOnly {
                return "Bu hesap \(status.providerLabel) ile açılmış — o düğmeyle giriş yap."
            }
        }
        return "E-posta veya şifre hatalı."
    }

    /// US-011 — Kayıt + KVKK açık rızası. Doğrulama e-postası beklenir,
    /// kullanıcı doğrudan içeri alınmaz.
    func signUp(name: String, email: String, password: String) async {
        authError = nil
        authInfo = nil
        guard supabaseReady else { login(); return }   // demo modu
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { authError = "Adını gir."; return }
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            authError = "E-posta adresini gir."
            return
        }
        guard password.count >= 8 else {
            authError = "Şifre en az 8 karakter olmalı."
            return
        }
        authBusy = true
        defer { authBusy = false }
        do {
            let result = try await SupabaseService.shared.signUp(
                fullName: trimmedName, email: email, password: password)
            switch result {
            case .alreadyRegistered:
                authError = "Bu e-posta zaten kullanımda, lütfen giriş yapın."
            case .signedIn:
                pendingEmail = email
                applyFullName(trimmedName)
                await enterApp()      // doğrulama kapalıysa (dev) doğrudan içeri
            case .needsVerification:
                pendingEmail = email
                applyFullName(trimmedName)
                screen = .verifyEmail
            }
        } catch {
            authError = Self.authMessage(error)
        }
    }

    /// US-017 — Doğrulama e-postasını yeniden gönder.
    func resendVerification() async {
        authError = nil
        authInfo = nil
        authBusy = true
        defer { authBusy = false }
        do {
            try await SupabaseService.shared.resendConfirmation(email: pendingEmail)
            authInfo = "Doğrulama e-postası tekrar gönderildi."
        } catch {
            authError = Self.authMessage(error)
        }
    }

    /// US-013 — Şifre sıfırlama isteği. Güvenlik gereği e-posta kayıtlı olsun
    /// olmasın aynı onay gösterilir (hesap varlığı sızdırılmaz).
    func sendPasswordReset(email: String) async {
        authError = nil
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            authError = "E-posta adresini gir."
            return
        }
        authBusy = true
        defer { authBusy = false }
        if supabaseReady {
            do {
                try await SupabaseService.shared.resetPassword(email: email)
            } catch {
                // Hata kullanıcıya YANSITILMAZ: adresin kayıtlı olup olmadığı
                // sızmasın (user enumeration). Yalnızca loglanır.
                AuthLog.warn("resetPassword", error)
            }
        }
        forgotSent = true
    }

    /// US-013 — E-postadaki bağlantıdan gelen kullanıcı yeni şifresini belirler.
    func setNewPassword(_ password: String, confirm: String) async {
        authError = nil
        guard password.count >= 8 else {
            authError = "Şifre en az 8 karakter olmalı."
            return
        }
        guard password == confirm else {
            authError = "Şifreler eşleşmiyor."
            return
        }
        authBusy = true
        defer { authBusy = false }
        // Supabase aynı şifreyi sessizce kabul ediyor; kontrolü biz yapıyoruz.
        if await SupabaseService.shared.isSameAsCurrentPassword(password) {
            authError = "Yeni şifre eskisinden farklı olmalı — başka bir şifre seç."
            return
        }
        do {
            try await SupabaseService.shared.updatePassword(password)
            authInfo = "Şifren güncellendi."
            await enterApp()
        } catch {
            authError = Self.authMessage(error)
        }
    }

    /// US-018 — Google / Apple ile giriş.
    func signInWithProvider(_ provider: Provider) async {
        authError = nil
        authInfo = nil
        guard supabaseReady else { login(); return }
        authBusy = true
        defer { authBusy = false }
        let enabled = await SupabaseService.shared.enabledProviders()
        guard enabled.contains(provider == .apple ? "apple" : "google") else {
            authError = provider == .apple
                ? "Apple ile giriş henüz etkin değil — Apple Developer hesabı bağlanınca açılacak."
                : "Google ile giriş henüz etkin değil — kurulum tamamlanınca açılacak."
            return
        }
        do {
            if provider == .google {
                // US-019 — native akış: Google izin ekranında Supabase alan adı
                // değil uygulamanın kendi kimliği görünür.
                let tokens = try await GoogleOAuth.shared.signIn()
                try await SupabaseService.shared.signInWithGoogle(tokens)
            } else {
                try await SupabaseService.shared.signInWithProvider(provider)
            }
            // Sağlayıcı e-postaları doğrulanmış sayılır.
            if let name = await SupabaseService.shared.syncProviderProfile() {
                applyFullName(name)
            }
            await enterApp()
        } catch let failure as GoogleOAuth.Failure {
            switch failure {
            case .cancelled:
                return   // kullanıcı vazgeçti → sessiz
            case .exchange:
                // Native akış düşerse eski web akışına geri düşülür — kullanıcı
                // yine giriş yapabilsin; hata yalnızca log'a gider.
                AuthLog.warn("googleNative", failure)
                await fallbackWebGoogle()
            }
        } catch {
            let message = Self.providerMessage(error, provider: provider)
            authError = message.isEmpty ? nil : message
        }
    }

    /// Native Google akışı düşerse Supabase'in web tabanlı OAuth'una dönüş.
    private func fallbackWebGoogle() async {
        do {
            try await SupabaseService.shared.signInWithProvider(.google)
            if let name = await SupabaseService.shared.syncProviderProfile() {
                applyFullName(name)
            }
            await enterApp()
        } catch {
            let message = Self.providerMessage(error, provider: .google)
            authError = message.isEmpty ? nil : message
        }
    }

    /// US-015 — Native Sign in with Apple sonucu.
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>, nonce: String?) {
        authError = nil
        authInfo = nil
        switch result {
        case .failure(let error):
            // Kullanıcı vazgeçtiyse sessiz kal
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            authError = Self.authMessage(error)

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce else {
                authError = "Apple girişi tamamlanamadı — tekrar dene."
                return
            }
            // Ad yalnızca ilk girişte gelir; sonraki girişlerde boştur.
            let appleName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)

            Task {
                authBusy = true
                defer { authBusy = false }
                do {
                    try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
                    if !appleName.isEmpty {
                        try? await SupabaseService.shared.updateFullName(appleName)
                        applyFullName(appleName)
                    } else if let name = await SupabaseService.shared.syncProviderProfile() {
                        applyFullName(name)
                    }
                    await enterApp()
                } catch {
                    authError = Self.authMessage(error)
                }
            }
        }
    }

    /// `halka://` ile açılan bağlantılar: e-posta doğrulama ve şifre sıfırlama.
    func handleDeepLink(_ url: URL) {
        guard supabaseReady else { return }
        let isReset = url.absoluteString.contains("reset-password")
        Task {
            do {
                try await SupabaseService.shared.session(from: url)
                if isReset {
                    authError = nil
                    screen = .newPassword
                } else {
                    authInfo = nil
                    await enterApp()
                }
            } catch {
                authError = "Bağlantı geçersiz veya süresi dolmuş — tekrar dene."
                screen = isReset ? .forgot : .login
            }
        }
    }

    /// US-016 (kısmi) — Profil adını buluttan yükle; selamlama gerçek isme döner.
    func loadProfile() async {
        if let name = await SupabaseService.shared.fetchFullName() {
            applyFullName(name)
        }
    }

    func applyFullName(_ name: String) {
        userFullName = name
        userName = name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Supabase hatalarını kullanıcı diline çevirir.
    static func authMessage(_ error: Error) -> String {
        if error is URLError {
            return "Bağlantı kurulamadı — internetini kontrol edip tekrar dene."
        }
        let text = error.localizedDescription.lowercased()
        if text.contains("network") || text.contains("connection") || text.contains("offline") {
            return "Bağlantı kurulamadı — internetini kontrol edip tekrar dene."
        }
        if text.contains("invalid login credentials") {
            return "E-posta veya şifre hatalı."
        }
        if text.contains("already registered") || text.contains("already been registered") {
            return "Bu e-posta zaten kayıtlı — giriş yapmayı dene."
        }
        if text.contains("invalid email") || text.contains("validate email")
            || text.contains("invalid format") {
            return "Geçerli bir e-posta adresi gir."
        }
        if text.contains("email not confirmed") {
            return "E-postan henüz doğrulanmamış — gelen kutundaki bağlantıya tıkla."
        }
        // Supabase bu durumu bazen düz metin, bazen `same_password` koduyla döndürür.
        if text.contains("same as the old") || text.contains("should be different")
            || text.contains("same_password") {
            return "Yeni şifre eskisinden farklı olmalı — başka bir şifre seç."
        }
        if text.contains("password") && (text.contains("least") || text.contains("short")) {
            return "Şifre çok kısa — en az 8 karakter kullan."
        }
        // Sıfırlama oturumu düşmüşse kullanıcıya ne yapacağını söyle.
        if text.contains("session missing") || text.contains("session_not_found")
            || text.contains("auth session") {
            return "Oturumun sona ermiş — e-postadaki sıfırlama bağlantısını tekrar aç."
        }
        if text.contains("expired") || text.contains("invalid token")
            || text.contains("token has expired") || text.contains("otp_expired") {
            return "Bağlantının süresi dolmuş — yeni bir bağlantı iste."
        }
        if text.contains("rate limit") || text.contains("too many requests")
            || text.contains("over_request_rate_limit") {
            return "Çok fazla deneme yapıldı — birkaç dakika sonra tekrar dene."
        }
        return "Bir şeyler ters gitti: \(error.localizedDescription)"
    }

    static func providerMessage(_ error: Error, provider: Provider) -> String {
        let name = provider == .apple ? "Apple" : "Google"
        let ns = error as NSError
        // ASWebAuthenticationSession: 1 = kullanıcı vazgeçti / oturum kapandı
        if ns.domain.contains("AuthenticationServices") && ns.code == 1 { return "" }
        let text = error.localizedDescription.lowercased()
        if text.contains("cancel") { return "" }   // kullanıcı vazgeçti — sessiz
        if text.contains("provider is not enabled") || text.contains("unsupported provider") {
            return "\(name) ile giriş henüz etkin değil — kurulum tamamlanınca açılacak."
        }
        return authMessage(error)
    }
}

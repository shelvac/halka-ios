import Foundation

// MARK: - Gerçek kimlik akışları (Sprint 1: US-010…US-014, US-016)
// Supabase yapılandırılmamışsa (anon key boş) her akış demo davranışına düşer;
// uygulama backend'siz de çalışmaya devam eder.

extension AppModel {

    var supabaseReady: Bool { SupabaseService.shared.isConfigured }

    /// US-010 — Splash: geçerli oturum varsa doğrudan ana ekrana.
    func finishSplash() async {
        guard screen == .splash else { return }
        if supabaseReady, await SupabaseService.shared.hasValidSession() {
            await loadProfile()
            role = .user
            screen = .app
        } else {
            screen = .login
        }
    }

    /// US-012 — E-posta ile giriş.
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
            await loadProfile()
            if loginRole == .dietitian {
                screen = .premium
            } else {
                role = .user
                screen = .app
            }
        } catch {
            authError = Self.authMessage(error)
        }
    }

    /// US-011 — Kayıt + KVKK açık rızası.
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
            let signedIn = try await SupabaseService.shared.signUp(
                fullName: trimmedName, email: email, password: password)
            if signedIn {
                applyFullName(trimmedName)
                role = .user
                screen = .app
            } else {
                // "Confirm email" açık: önce e-posta doğrulaması gerekiyor.
                authInfo = "Doğrulama e-postası gönderildi — gelen kutunu kontrol et, sonra giriş yap."
                screen = .login
            }
        } catch {
            authError = Self.authMessage(error)
        }
    }

    /// US-013 — Şifre sıfırlama. Güvenlik gereği e-posta kayıtlı olsun olmasın
    /// aynı onay gösterilir (hesap varlığı sızdırılmaz).
    func sendPasswordReset(email: String) async {
        authError = nil
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            authError = "E-posta adresini gir."
            return
        }
        authBusy = true
        defer { authBusy = false }
        if supabaseReady {
            try? await SupabaseService.shared.resetPassword(email: email)
        }
        forgotSent = true
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
        if text.contains("password") && (text.contains("least") || text.contains("short")) {
            return "Şifre çok kısa — en az 8 karakter kullan."
        }
        return "Bir şeyler ters gitti: \(error.localizedDescription)"
    }
}

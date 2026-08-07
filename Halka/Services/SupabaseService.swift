import Foundation
import Supabase

/// ADR-002 bağlantı ayarları.
///
/// `anonKey` Supabase'in İSTEMCİYE AÇIK anahtarıdır (uygulama paketine gömülür,
/// güvenlik RLS politikalarındadır) — bu yüzden repoya girmesi kabul edilebilir.
/// ASLA buraya konulmayacak olan: `service_role` anahtarı (Dashboard'da "secret").
enum SupabaseConfig {
    static let url = "https://urrjkubdngoszkttpeph.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVycmprdWJkbmdvc3prdHRwZXBoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMDA2MTcsImV4cCI6MjEwMTU3NjYxN30.Iy-48jUSh4ku-9ZRAPx6T0vDtINY3SKeunJRRA9qyd8"

    /// E-posta bağlantıları ve OAuth dönüşleri uygulamaya bu şemayla döner
    /// (Halka-Info.plist'te kayıtlı, Supabase Redirect URLs listesinde tanımlı).
    static let loginCallback = URL(string: "halka://login-callback")!
    static let resetCallback = URL(string: "halka://reset-password")!
}

/// Supabase istemcisi + auth ve profil operasyonları (US-002, US-010…US-017).
final class SupabaseService {
    static let shared = SupabaseService()
    let client: SupabaseClient?

    private init() {
        if !SupabaseConfig.anonKey.isEmpty, let url = URL(string: SupabaseConfig.url) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
        } else {
            client = nil
        }
    }

    var isConfigured: Bool { client != nil }

    // MARK: Oturum

    /// Kayıtlı oturum var mı? (gerekiyorsa token'ı da yeniler — US-010)
    func hasValidSession() async -> Bool {
        guard let client else { return false }
        return (try? await client.auth.session) != nil
    }

    /// Oturumdaki kullanıcının e-postası doğrulanmış mı? (US-011 · isEmailVerified)
    func isEmailVerified() async -> Bool {
        guard let client, let session = try? await client.auth.session else { return false }
        return session.user.emailConfirmedAt != nil
    }

    /// Oturumdaki kullanıcı (session üzerinden — sürümler arası en güvenli yol).
    private func currentUser() async -> User? {
        guard let client, let session = try? await client.auth.session else { return nil }
        return session.user
    }

    func currentEmail() async -> String? {
        await currentUser()?.email
    }

    func signIn(email: String, password: String) async throws {
        guard let client else { return }
        try await client.auth.signIn(email: email, password: password)
    }

    enum SignUpResult { case signedIn, needsVerification, alreadyRegistered }

    /// Kayıt olur.
    /// - `signedIn`: doğrulama kapalı, oturum açıldı
    /// - `needsVerification`: doğrulama e-postası gönderildi
    /// - `alreadyRegistered`: e-posta zaten kayıtlı (Supabase, hesap varlığını
    ///   sızdırmamak için hata yerine boş `identities` döndürür)
    func signUp(fullName: String, email: String, password: String) async throws -> SignUpResult {
        guard let client else { return .needsVerification }
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)],
            redirectTo: SupabaseConfig.loginCallback)
        if response.session != nil {
            try? await markConsents()
            return .signedIn
        }
        if let identities = response.user.identities, identities.isEmpty {
            return .alreadyRegistered
        }
        return .needsVerification
    }

    /// Supabase'de etkin olan sosyal sağlayıcılar (tarayıcı açmadan kontrol için).
    func enabledProviders() async -> Set<String> {
        guard let url = URL(string: SupabaseConfig.url + "/auth/v1/settings") else { return [] }
        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let external = json["external"] as? [String: Any] else { return [] }
        return Set(external.compactMap { key, value in (value as? Bool) == true ? key : nil })
    }

    /// Doğrulama e-postasını yeniden gönderir (US-017).
    func resendConfirmation(email: String) async throws {
        guard let client else { return }
        try await client.auth.resend(email: email, type: .signup,
                                     emailRedirectTo: SupabaseConfig.loginCallback)
    }

    /// KVKK aydınlatma + sağlık verisi açık rızası zaman damgaları (US-011).
    func markConsents() async throws {
        guard let client, let user = await currentUser() else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("users")
            .update(["kvkk_accepted_at": now, "health_consent_at": now])
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    /// Bir e-postanın kayıtlı olup olmadığı ve hangi yöntemle açıldığı (US-013).
    struct AccountStatus: Decodable {
        let exists: Bool
        let has_password: Bool
        let providers: String

        var isOAuthOnly: Bool { exists && !has_password && !providers.isEmpty }
        var providerLabel: String {
            let names = providers.split(separator: ",").map(String.init)
            if names.contains("apple") && names.contains("google") { return "Apple veya Google" }
            if names.contains("apple") { return "Apple" }
            if names.contains("google") { return "Google" }
            return "sosyal hesap"
        }
    }

    /// Sunucudaki `account_status` fonksiyonunu çağırır. Fonksiyon henüz
    /// uygulanmadıysa veya ağ hatası olursa `nil` döner (akış eskisi gibi sürer).
    func accountStatus(email: String) async -> AccountStatus? {
        guard let client else { return nil }
        return try? await client
            .rpc("account_status", params: ["p_email": email])
            .execute()
            .value
    }

    func resetPassword(email: String) async throws {
        guard let client else { return }
        try await client.auth.resetPasswordForEmail(email, redirectTo: SupabaseConfig.resetCallback)
    }

    /// Şifre sıfırlama akışının son adımı (US-013).
    func updatePassword(_ newPassword: String) async throws {
        guard let client else { return }
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    /// Girilen şifre kullanıcının MEVCUT şifresiyle aynı mı?
    ///
    /// Sıfırlama akışında kullanıcı eski şifresini yazmaz, Supabase'de de
    /// "aynı şifreyi reddet" diye bir ayar yok. Bu yüzden kontrolü kendimiz
    /// yapıyoruz: yeni şifreyle giriş denenir — başarılı olursa şifre eskisiyle
    /// aynıdır. Deneme AYRI bir istemciyle yapılır ki sıfırlama oturumu
    /// bozulmasın; sonuç ne olursa olsun o istemcinin oturumu kapatılır.
    ///
    /// Ağ hatası gibi belirsiz durumlarda `false` döner — kontrol kullanıcıyı
    /// bloke etmemeli, sadece uyarı amaçlıdır.
    func isSameAsCurrentPassword(_ password: String) async -> Bool {
        guard let email = await currentEmail(),
              let url = URL(string: SupabaseConfig.url) else { return false }
        let probe = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
        defer { Task { try? await probe.auth.signOut() } }
        do {
            try await probe.auth.signIn(email: email, password: password)
            return true          // giriş yapabildi → şifre aynı
        } catch {
            return false         // giriş yapamadı → şifre farklı (ya da ağ hatası)
        }
    }

    func signOut() async {
        try? await client?.auth.signOut()
    }

    /// US-021 — Hesabı ve tüm verisini siler (KVKK md. 7).
    ///
    /// Önce `delete-account` Edge Function'ı denenir: veda e-postasını gönderip
    /// hesabı service_role ile siler. Fonksiyon dağıtılmamışsa ya da hata
    /// verirse SQL yedeğine (`delete_account()`) düşülür — kullanıcının silme
    /// hakkı e-posta altyapısına bağlı olmamalı. İki yolda da cascade zinciri
    /// veriyi temizler (0003_delete_account.sql).
    /// Silme sonrası oturum kapatılır — token geçersiz olsa da yerel iz kalmasın.
    func deleteAccount() async throws {
        guard let client else { return }
        do {
            _ = try await client.functions.invoke("delete-account")
        } catch {
            AuthLog.warn("deleteAccount/edge", error)
            try await client.rpc("delete_account").execute()
        }
        await signOut()
    }

    // MARK: SSO (US-018 · Google · Apple)

    /// Sağlayıcıyla giriş — ASWebAuthenticationSession üzerinden, dönüşte
    /// `halka://login-callback` ile uygulamaya geri gelir.
    func signInWithProvider(_ provider: Provider) async throws {
        guard let client else { return }
        try await client.auth.signInWithOAuth(
            provider: provider,
            redirectTo: SupabaseConfig.loginCallback)
    }

    /// Native Sign in with Apple — Apple'ın verdiği identity token'ı Supabase
    /// oturumuna çevirir (tarayıcı açılmaz).
    func signInWithApple(idToken: String, nonce: String) async throws {
        guard let client else { return }
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
    }

    /// E-posta bağlantısı / OAuth dönüşündeki kodu oturuma çevirir.
    @discardableResult
    func session(from url: URL) async throws -> Bool {
        guard let client else { return false }
        try await client.auth.session(from: url)
        return true
    }

    // MARK: Profil (US-016)

    private struct ProfileRow: Decodable {
        let full_name: String?
    }

    func fetchFullName() async -> String? {
        guard let client, let user = await currentUser() else { return nil }
        let row: ProfileRow? = try? await client.from("users")
            .select("full_name")
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()
            .value
        let name = row?.full_name?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? nil : name
    }

    func updateFullName(_ name: String) async throws {
        guard let client, let user = await currentUser() else { return }
        try await client.from("users")
            .update(["full_name": name])
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    /// SSO ile gelen kullanıcıda profil adı boşsa sağlayıcıdan gelen adı yazar.
    func syncProviderProfile() async -> String? {
        guard let user = await currentUser() else { return nil }
        if let existing = await fetchFullName() { return existing }
        let metadata = user.userMetadata
        let name = (metadata["full_name"]?.stringValue
                    ?? metadata["name"]?.stringValue
                    ?? "").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        try? await updateFullName(name)
        return name
    }
}

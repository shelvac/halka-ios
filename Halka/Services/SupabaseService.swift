import Foundation
import Supabase

/// ADR-002 bağlantı ayarları.
///
/// `anonKey` Supabase'in İSTEMCİYE AÇIK anahtarıdır (uygulama paketine gömülür,
/// güvenlik RLS politikalarındadır) — bu yüzden repoya girmesi kabul edilebilir.
/// ASLA buraya konulmayacak olan: `service_role` anahtarı (Dashboard'da "secret").
enum SupabaseConfig {
    static let url = "https://urrjkubdngoszkttpeph.supabase.co"
    /// Dashboard → Project Settings → API → "anon public" anahtarını buraya yapıştır.
    /// Boş bırakılırsa uygulama demo modunda çalışır (giriş düğmeleri eski davranış).
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVycmprdWJkbmdvc3prdHRwZXBoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMDA2MTcsImV4cCI6MjEwMTU3NjYxN30.Iy-48jUSh4ku-9ZRAPx6T0vDtINY3SKeunJRRA9qyd8"
}

/// Supabase istemcisi + auth ve profil operasyonları (US-002, US-010…US-016).
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

    /// Kayıtlı oturum var mı? (`auth.session` gerekiyorsa token'ı da yeniler — US-010)
    func hasValidSession() async -> Bool {
        guard let client else { return false }
        return (try? await client.auth.session) != nil
    }

    func signIn(email: String, password: String) async throws {
        guard let client else { return }
        try await client.auth.signIn(email: email, password: password)
    }

    /// Kayıt olur; oturum hemen açıldıysa true döner
    /// (Supabase'te "Confirm email" kapalıysa). Açıksa kullanıcı önce
    /// e-postasını doğrulamalıdır ve false döner.
    func signUp(fullName: String, email: String, password: String) async throws -> Bool {
        guard let client else { return false }
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)])
        if response.session != nil {
            try? await markConsents()
            return true
        }
        return false
    }

    /// KVKK aydınlatma + sağlık verisi açık rızası zaman damgaları (US-011).
    func markConsents() async throws {
        guard let client, let user = client.auth.currentUser else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from("users")
            .update(["kvkk_accepted_at": now, "health_consent_at": now])
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    func resetPassword(email: String) async throws {
        guard let client else { return }
        try await client.auth.resetPasswordForEmail(email)
    }

    func signOut() async {
        try? await client?.auth.signOut()
    }

    // MARK: Profil (US-016)

    private struct ProfileRow: Decodable {
        let full_name: String?
    }

    func fetchFullName() async -> String? {
        guard let client, let user = client.auth.currentUser else { return nil }
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
        guard let client, let user = client.auth.currentUser else { return }
        try await client.from("users")
            .update(["full_name": name])
            .eq("id", value: user.id.uuidString)
            .execute()
    }
}

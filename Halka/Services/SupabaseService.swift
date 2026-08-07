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

    /// Sağlık verisi açık rızasını geri çeker (KVKK m.6 — rıza her an geri
    /// alınabilir olmalı). Aydınlatma onayı korunur; geri çekilen yalnızca
    /// sağlık verisi işleme rızasıdır.
    func withdrawHealthConsent() async throws {
        guard let client, let user = await currentUser() else { return }
        try await client.from("users")
            .update(["health_consent_at": AnyJSON.null])
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    // MARK: Profil (US-016)

    /// `users` satırının okunan hâli. Sunucu tarihleri `yyyy-MM-dd` (date) ve
    /// ISO-8601 (timestamptz) olarak döndürdüğü için ayrıştırma burada yapılır.
    private struct ProfileRow: Decodable {
        let full_name: String?
        let avatar_path: String?
        let birth_date: String?
        let sex: String?
        let height_cm: Double?
        let weight_kg: Double?
        let target_weight_kg: Double?
        let activity_level: String?
        let profile_completed_at: String?
        let kvkk_accepted_at: String?
        let health_consent_at: String?
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Oturumdaki kullanıcının profili. Satır yoksa veya ağ hatasında `nil`.
    func fetchProfile() async -> Profile? {
        guard let client, let user = await currentUser() else { return nil }
        guard let rows: [ProfileRow] = try? await client.from("users")
            .select("full_name,avatar_path,birth_date,sex,height_cm,weight_kg,target_weight_kg,activity_level,profile_completed_at,kvkk_accepted_at,health_consent_at")
            .eq("id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value,
            let row = rows.first else { return nil }

        var profile = Profile()
        profile.fullName = row.full_name ?? ""
        profile.avatarPath = row.avatar_path
        profile.birthDate = row.birth_date.flatMap { Self.dayFormatter.date(from: $0) }
        profile.sex = row.sex.flatMap(Profile.Sex.init(rawValue:))
        profile.heightCm = row.height_cm
        profile.weightKg = row.weight_kg
        profile.targetWeightKg = row.target_weight_kg
        profile.activityLevel = row.activity_level.flatMap(Profile.ActivityLevel.init(rawValue:))
        profile.completedAt = row.profile_completed_at.flatMap(Self.timestamp)
        profile.kvkkAcceptedAt = row.kvkk_accepted_at.flatMap(Self.timestamp)
        profile.healthConsentAt = row.health_consent_at.flatMap(Self.timestamp)
        return profile
    }

    /// Postgres timestamptz'i ayrıştırır. Sunucu kesirli saniyeyi bazen
    /// döndürüp bazen döndürmediği için iki biçim de denenir.
    private static func timestamp(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    /// Profili kaydeder. Zorunlu alanlar tamamsa `profile_completed_at` damgalanır
    /// (US-026 onboarding akışı bu damgaya bakacak).
    func saveProfile(_ profile: Profile) async throws {
        guard let client, let user = await currentUser() else { return }

        // PostgREST'e karışık tipli sözlük gönderilemiyor; JSON'a çevirip yolluyoruz.
        var payload: [String: AnyJSON] = [:]
        payload["full_name"] = .string(profile.fullName)
        payload["birth_date"] = profile.birthDate
            .map { .string(Self.dayFormatter.string(from: $0)) } ?? .null
        payload["sex"] = profile.sex.map { .string($0.rawValue) } ?? .null
        payload["height_cm"] = profile.heightCm.map { .double($0) } ?? .null
        payload["weight_kg"] = profile.weightKg.map { .double($0) } ?? .null
        payload["target_weight_kg"] = profile.targetWeightKg.map { .double($0) } ?? .null
        payload["activity_level"] = profile.activityLevel.map { .string($0.rawValue) } ?? .null
        if profile.isComplete {
            payload["profile_completed_at"] =
                .string(ISO8601DateFormatter().string(from: profile.completedAt ?? Date()))
        }

        try await client.from("users")
            .update(payload)
            .eq("id", value: user.id.uuidString)
            .execute()
    }

    // MARK: Günlük halka verisi (US-024)

    /// `rings_daily` satırı. Gün "yyyy-MM-dd" olarak tutulur.
    struct RingsRow: Codable {
        let day: String
        let exercise_min: Int
        let water_ml: Int
        let sleep_hours: Double
        let nutrition_kcal: Int
    }

    /// Bir tarih aralığındaki günlük kayıtlar (takvim geçmişi için).
    func fetchRings(from start: Date, to end: Date) async -> [String: RingsRow] {
        guard let client, let user = await currentUser() else { return [:] }
        guard let rows: [RingsRow] = try? await client.from("rings_daily")
            .select("day,exercise_min,water_ml,sleep_hours,nutrition_kcal")
            .eq("user_id", value: user.id.uuidString)
            .gte("day", value: Self.dayFormatter.string(from: start))
            .lte("day", value: Self.dayFormatter.string(from: end))
            .execute()
            .value else { return [:] }
        return Dictionary(rows.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// Bugünün değerlerini yazar. `(user_id, day)` benzersiz olduğu için
    /// upsert kullanılıyor — aynı gün defalarca güncellenebilir.
    func saveRings(day: Date, exerciseMin: Int, waterML: Int,
                   sleepHours: Double, nutritionKcal: Int) async throws {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "day": .string(Self.dayFormatter.string(from: day)),
            "exercise_min": .integer(exerciseMin),
            "water_ml": .integer(waterML),
            "sleep_hours": .double(sleepHours),
            "nutrition_kcal": .integer(nutritionKcal)
        ]
        try await client.from("rings_daily")
            .upsert(payload, onConflict: "user_id,day")
            .execute()
    }

    // MARK: Profil fotoğrafı (US-016)

    /// Fotoğrafı `avatars` bucket'ına yükler ve yolunu profile yazar.
    /// Yol kullanıcının kendi id'siyle başlar; RLS politikaları başkasının
    /// klasörüne yazmayı engelliyor (0005_avatars.sql).
    @discardableResult
    func uploadAvatar(_ data: Data) async throws -> String {
        guard let client, let user = await currentUser() else { return "" }
        // Yol küçük harfli: storage RLS politikaları düz metin karşılaştırması
        // yapıyor, Swift'in ürettiği BÜYÜK harfli UUID ile eşleşmiyordu.
        let path = "\(user.id.uuidString.lowercased())/avatar.jpg"

        try await client.storage.from("avatars").upload(
            path, data: data,
            options: FileOptions(cacheControl: "3600",
                                 contentType: "image/jpeg",
                                 upsert: true))

        try await client.from("users")
            .update(["avatar_path": path])
            .eq("id", value: user.id.uuidString)
            .execute()
        return path
    }

    /// Profil fotoğrafını indirir. Dosya yoksa veya erişilemezse `nil`.
    func downloadAvatar(path: String) async -> Data? {
        guard let client else { return nil }
        return try? await client.storage.from("avatars").download(path: path)
    }

    /// Fotoğrafı siler ve profildeki yolu boşaltır.
    func removeAvatar() async throws {
        guard let client, let user = await currentUser() else { return }
        // Yol küçük harfli: storage RLS politikaları düz metin karşılaştırması
        // yapıyor, Swift'in ürettiği BÜYÜK harfli UUID ile eşleşmiyordu.
        let path = "\(user.id.uuidString.lowercased())/avatar.jpg"
        _ = try? await client.storage.from("avatars").remove(paths: [path])
        try await client.from("users")
            .update(["avatar_path": AnyJSON.null])
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
    /// yapıyoruz: yeni şifreyle giriş denenir — sunucu 200 dönerse şifre
    /// eskisiyle aynıdır.
    ///
    /// Doğrudan HTTP ile sorulur, SDK istemcisiyle DEĞİL: ikinci bir
    /// `SupabaseClient` aynı yerel oturum deposunu paylaşıyor, dolayısıyla
    /// giriş/çıkış yapması sıfırlama oturumunu siliyor ve şifre güncellemesi
    /// "Auth session missing" ile düşüyordu. Buradaki istek hiçbir yere
    /// oturum yazmaz; dönen token'lar kullanılmadan atılır.
    ///
    /// Ağ hatası gibi belirsiz durumlarda `false` döner — kontrol kullanıcıyı
    /// bloke etmemeli, sadece uyarı amaçlıdır.
    func isSameAsCurrentPassword(_ password: String) async -> Bool {
        guard let email = await currentEmail(),
              let url = URL(string: SupabaseConfig.url + "/auth/v1/token?grant_type=password")
        else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["email": email, "password": password])

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
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

    /// US-019 — Native Google girişi: `GoogleOAuth`'un ürettiği id_token'ı
    /// Supabase oturumuna çevirir. iOS istemci ID'si Supabase'de
    /// `external_google_client_id` listesinde kayıtlı olmalıdır.
    func signInWithGoogle(_ tokens: GoogleOAuth.Tokens) async throws {
        guard let client else { return }
        try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .google,
                                                  idToken: tokens.idToken,
                                                  accessToken: tokens.accessToken,
                                                  nonce: tokens.nonce))
    }

    /// E-posta bağlantısı / OAuth dönüşündeki kodu oturuma çevirir.
    @discardableResult
    func session(from url: URL) async throws -> Bool {
        guard let client else { return false }
        try await client.auth.session(from: url)
        return true
    }

    // MARK: Profil (US-016)

    private struct NameRow: Decodable {
        let full_name: String?
    }

    func fetchFullName() async -> String? {
        guard let client, let user = await currentUser() else { return nil }
        let row: NameRow? = try? await client.from("users")
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

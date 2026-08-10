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

    /// Gün anahtarı ("yyyy-MM-dd") — uygulamanın TEK kaynağı.
    ///
    /// Dikkat: saat dilimi **yerel**. Eskiden UTC'ye sabitti ve `AppModel`
    /// yerel formatlayıcı kullanıyordu; "bugün" yerel gece yarısı olduğu için
    /// UTC'de bir önceki güne düşüyordu. Sonuç: veri "2026-08-07" satırına
    /// yazılıp "2026-08-08" olarak aranıyor, bulunamıyor ve kaybolmuş
    /// görünüyordu (su, uyku, seri hepsi bundan etkilendi).
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Oturumdaki kullanıcının profili. Satır yoksa veya ağ hatasında `nil`.
    func fetchProfile() async -> Profile? {
        guard let client, let user = await currentUser() else { return nil }
        let rows: [ProfileRow]
        do {
            rows = try await client.from("users")
                .select("full_name,avatar_path,birth_date,sex,height_cm,weight_kg,target_weight_kg,activity_level,profile_completed_at,kvkk_accepted_at,health_consent_at")
                .eq("id", value: user.id.uuidString)
                .limit(1)
                .execute()
                .value
        } catch {
            // Sessiz nil, "profilim uçtu" olarak yaşanıyordu — sebep görünsün.
            AuthLog.warn("fetchProfile", error)
            return nil
        }
        guard let row = rows.first else { return nil }

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
        //
        // BOŞ ALAN GÖNDERİLMEZ (null yazılmaz): bellekteki profil herhangi
        // bir nedenle eksikse (yükleme hatası, oturum yarışı) sunucudaki
        // dolu alanları silmemeli. Simge'nin doğum/boy/aktivite verisi tam
        // böyle uçtu — kilo eşitlemesi boş profille çalışıp gerisini ezdi.
        // Profil ekranı alan silmeye izin vermiyor; atlamak güvenli.
        var payload: [String: AnyJSON] = [:]
        if !profile.fullName.isEmpty { payload["full_name"] = .string(profile.fullName) }
        if let birth = profile.birthDate {
            payload["birth_date"] = .string(Self.dayFormatter.string(from: birth))
        }
        if let sex = profile.sex { payload["sex"] = .string(sex.rawValue) }
        if let height = profile.heightCm { payload["height_cm"] = .double(height) }
        if let weight = profile.weightKg { payload["weight_kg"] = .double(weight) }
        if let target = profile.targetWeightKg { payload["target_weight_kg"] = .double(target) }
        if let activity = profile.activityLevel { payload["activity_level"] = .string(activity.rawValue) }
        guard !payload.isEmpty || profile.isComplete else { return }
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
        var steps: Int = 0
        var active_energy_kcal: Int = 0
    }

    /// Bir tarih aralığındaki günlük kayıtlar (takvim geçmişi için).
    /// Hata **yutulmaz**: ağ koptuğunda boş sözlük dönmek "bu kullanıcının
    /// hiç verisi yok" anlamına gelirdi ve ardından gelen kayıt, duran veriyi
    /// sıfırla ezerdi. Çağıran tarafın başarısızlığı görmesi şart.
    func fetchRings(from start: Date, to end: Date) async throws -> [String: RingsRow] {
        guard let client, let user = await currentUser() else { return [:] }
        let rows: [RingsRow] = try await client.from("rings_daily")
            .select("day,exercise_min,water_ml,sleep_hours,nutrition_kcal,steps,active_energy_kcal")
            .eq("user_id", value: user.id.uuidString)
            .gte("day", value: Self.dayFormatter.string(from: start))
            .lte("day", value: Self.dayFormatter.string(from: end))
            .execute()
            .value
        return Dictionary(rows.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// Bugünün değerlerini yazar. `(user_id, day)` benzersiz olduğu için
    /// upsert kullanılıyor — aynı gün defalarca güncellenebilir.
    func saveRings(day: Date, exerciseMin: Int, waterML: Int,
                   sleepHours: Double, nutritionKcal: Int,
                   steps: Int = 0, activeEnergy: Int = 0) async throws {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "day": .string(Self.dayFormatter.string(from: day)),
            "exercise_min": .integer(exerciseMin),
            "water_ml": .integer(waterML),
            "sleep_hours": .double(sleepHours),
            "nutrition_kcal": .integer(nutritionKcal),
            "steps": .integer(steps),
            "active_energy_kcal": .integer(activeEnergy)
        ]
        try await client.from("rings_daily")
            .upsert(payload, onConflict: "user_id,day")
            .execute()
    }

    /// Bugünü "uygulama açıldı" olarak işaretler (seri hesabı için).
    ///
    /// Ayrı bir istek: `saveRings` bu sütunu hiç göndermiyor, böylece Health
    /// aktarımı seriyi bozamıyor (upsert yalnızca gönderilen sütunları yazar).
    func markVisited(day: Date) async throws {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "day": .string(Self.dayFormatter.string(from: day)),
            "visited": .bool(true)
        ]
        try await client.from("rings_daily")
            .upsert(payload, onConflict: "user_id,day")
            .execute()
    }

    // MARK: Öğün kaydı (0010_meal_state.sql)

    /// Haftalık öğün durumu — işaretlenen öğünler, ekstralar, menü değişiklikleri.
    struct MealStateRow: Codable {
        var week_start: String
        var eaten: [String]
        var extras: [ExtraRow]
        var overrides: [String: String]
        /// Menüden kaldırılan plan öğünleri (0014). Eski satırlarda yok.
        var removed: [String]?
        /// Hızlı ekle sayaçları: yemek adı → kaç kez eklendi (0025).
        var quick_counts: [String: Int]?

        struct ExtraRow: Codable {
            var day: Int
            var title: String
            var kcal: Int
            var time: String
        }
    }

    /// Kayıtlı öğün durumu. Bulunamazsa `nil` — çağıran taraf bunu "kayıt yok"
    /// olarak ele alır; hata durumunda ise atar, çünkü boş dönmek kullanıcının
    /// işaretlerini silmek anlamına gelirdi.
    func fetchMealState() async throws -> MealStateRow? {
        guard let client, let user = await currentUser() else { return nil }
        let rows: [MealStateRow] = try await client.from("meal_state")
            .select("week_start,eaten,extras,overrides,removed,quick_counts")
            .eq("user_id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func saveMealState(weekStart: Date, eaten: [String],
                       extras: [MealStateRow.ExtraRow],
                       overrides: [String: String],
                       removed: [String],
                       quickCounts: [String: Int]) async throws {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "week_start": .string(Self.dayFormatter.string(from: weekStart)),
            "eaten": .array(eaten.map { .string($0) }),
            "extras": .array(extras.map {
                .object(["day": .integer($0.day), "title": .string($0.title),
                         "kcal": .integer($0.kcal), "time": .string($0.time)])
            }),
            "overrides": .object(overrides.mapValues { .string($0) }),
            "removed": .array(removed.map { .string($0) }),
            "quick_counts": .object(quickCounts.mapValues { .integer($0) })
        ]
        try await client.from("meal_state")
            .upsert(payload, onConflict: "user_id")
            .execute()
    }

    private struct VisitRow: Decodable { let day: String }

    /// Uygulamanın açıldığı günler ("yyyy-MM-dd").
    func fetchVisitedDays(since start: Date) async -> Set<String> {
        guard let client, let user = await currentUser() else { return [] }
        guard let rows: [VisitRow] = try? await client.from("rings_daily")
            .select("day")
            .eq("user_id", value: user.id.uuidString)
            .eq("visited", value: true)
            .gte("day", value: Self.dayFormatter.string(from: start))
            .execute()
            .value else { return [] }
        return Set(rows.map(\.day))
    }

    /// Birden çok günü tek istekte yazar (Apple Health geçmişi aktarımı).
    func saveRingsBatch(_ rows: [RingsRow], userID: String) async throws {
        guard let client, !rows.isEmpty else { return }
        let payload: [[String: AnyJSON]] = rows.map { row in
            ["user_id": .string(userID.lowercased()),
             "day": .string(row.day),
             "exercise_min": .integer(row.exercise_min),
             "water_ml": .integer(row.water_ml),
             "sleep_hours": .double(row.sleep_hours),
             "nutrition_kcal": .integer(row.nutrition_kcal),
             "steps": .integer(row.steps),
             "active_energy_kcal": .integer(row.active_energy_kcal)]
        }
        try await client.from("rings_daily")
            .upsert(payload, onConflict: "user_id,day")
            .execute()
    }

    /// Oturumdaki kullanıcının kimliği (toplu yazımda gerekiyor).
    func currentUserID() async -> String? {
        await currentUser()?.id.uuidString
    }

    // MARK: Vücut ölçümleri (US-025)

    private struct BodyRow: Codable {
        let id: UUID
        let measured_at: String
        let weight_kg: Double?
        let bmi: Double?
        let fat_percent: Double?
        let fat_mass_kg: Double?
        let skeletal_muscle_percent: Double?
        let skeletal_muscle_kg: Double?
        let muscle_percent: Double?
        let muscle_mass_kg: Double?
        let visceral_fat: Double?
        let water_percent: Double?
        let water_mass_kg: Double?
        let bmr_kcal: Int?
        let obesity_percent: Double?
        let bone_mass_kg: Double?
        let protein_percent: Double?
        let lean_mass_kg: Double?
        let metabolic_age: Int?
        let source: String
        let photo_path: String?
    }

    /// Ölçümler, yeniden eskiye. Karşılaştırma için sıra önemli.
    func fetchBodyMeasurements(limit: Int = 60) async -> [BodyMeasurement] {
        guard let client, let user = await currentUser() else { return [] }
        guard let rows: [BodyRow] = try? await client.from("body_measurements")
            .select()
            .eq("user_id", value: user.id.uuidString)
            .order("measured_at", ascending: false)
            .limit(limit)
            .execute()
            .value else { return [] }

        return rows.map { row in
            BodyMeasurement(
                id: row.id,
                measuredAt: Self.timestamp(row.measured_at) ?? Date(),
                weightKg: row.weight_kg,
                bmi: row.bmi,
                fatPercent: row.fat_percent,
                fatMassKg: row.fat_mass_kg,
                skeletalMusclePercent: row.skeletal_muscle_percent,
                skeletalMuscleKg: row.skeletal_muscle_kg,
                musclePercent: row.muscle_percent,
                muscleMassKg: row.muscle_mass_kg,
                visceralFat: row.visceral_fat,
                waterPercent: row.water_percent,
                waterMassKg: row.water_mass_kg,
                bmrKcal: row.bmr_kcal,
                obesityPercent: row.obesity_percent,
                boneMassKg: row.bone_mass_kg,
                proteinPercent: row.protein_percent,
                leanMassKg: row.lean_mass_kg,
                metabolicAge: row.metabolic_age,
                source: BodyMeasurement.Source(rawValue: row.source) ?? .manual,
                photoPath: row.photo_path)
        }
    }

    /// Ölçümü kaydeder. Aynı zaman damgası tekrar gelirse günceller
    /// (fotoğraf yeniden yüklenirse kopya oluşmasın).
    func saveBodyMeasurement(_ measurement: BodyMeasurement) async throws {
        guard let client, let user = await currentUser() else { return }
        func num(_ value: Double?) -> AnyJSON { value.map { .double($0) } ?? .null }
        func int(_ value: Int?) -> AnyJSON { value.map { .integer($0) } ?? .null }

        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "measured_at": .string(ISO8601DateFormatter().string(from: measurement.measuredAt)),
            "weight_kg": num(measurement.weightKg),
            "bmi": num(measurement.bmi),
            "fat_percent": num(measurement.fatPercent),
            "fat_mass_kg": num(measurement.fatMassKg),
            "skeletal_muscle_percent": num(measurement.skeletalMusclePercent),
            "skeletal_muscle_kg": num(measurement.skeletalMuscleKg),
            "muscle_percent": num(measurement.musclePercent),
            "muscle_mass_kg": num(measurement.muscleMassKg),
            "visceral_fat": num(measurement.visceralFat),
            "water_percent": num(measurement.waterPercent),
            "water_mass_kg": num(measurement.waterMassKg),
            "bmr_kcal": int(measurement.bmrKcal),
            "obesity_percent": num(measurement.obesityPercent),
            "bone_mass_kg": num(measurement.boneMassKg),
            "protein_percent": num(measurement.proteinPercent),
            "lean_mass_kg": num(measurement.leanMassKg),
            "metabolic_age": int(measurement.metabolicAge),
            "source": .string(measurement.source.rawValue),
            "photo_path": measurement.photoPath.map { .string($0) } ?? .null
        ]
        try await client.from("body_measurements")
            .upsert(payload, onConflict: "user_id,measured_at")
            .execute()
    }

    func deleteBodyMeasurement(id: UUID) async throws {
        guard let client, let user = await currentUser() else { return }
        // RLS zaten koruyor; user_id filtresi savunmayı derinleştirir —
        // politika bir gün gevşetilse bile başkasının kaydı silinemez.
        try await client.from("body_measurements")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: user.id.uuidString)
            .execute()
    }

    /// Tartı ekranı fotoğrafını saklar (kaynağı doğrulanabilsin diye).
    @discardableResult
    func uploadScalePhoto(_ data: Data, measuredAt: Date) async throws -> String {
        guard let client, let user = await currentUser() else { return "" }
        let stamp = Int(measuredAt.timeIntervalSince1970)
        let path = "\(user.id.uuidString.lowercased())/\(stamp).jpg"
        try await client.storage.from("scale-photos").upload(
            path, data: data,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
        return path
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

    // MARK: Belgelerim (US-025) — tahlil/tartı PDF'leri, kullanıcıya özel klasör.

    struct DocumentFile: Identifiable, Equatable {
        /// Bucket içindeki tam yol: "<uid>/<epoch>-<ad>.pdf".
        let path: String
        /// Gösterilen ad — epoch öneki soyulmuş hâli.
        let displayName: String
        let createdAt: Date?
        var id: String { path }
    }

    /// PDF'i kullanıcının klasörüne yükler; bucket yolu döner.
    func uploadDocument(_ data: Data, filename: String) async throws -> String {
        guard let client, let user = await currentUser() else { return "" }
        // Yol RLS ile eşleşsin diye küçük harfli uid; ad, yol kırıcı
        // karakterlerden arındırılır.
        let safe = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let stamp = Int(Date().timeIntervalSince1970)
        let path = "\(user.id.uuidString.lowercased())/\(stamp)-\(safe)"
        try await client.storage.from("documents").upload(
            path, data: data,
            options: FileOptions(cacheControl: "3600",
                                 contentType: "application/pdf",
                                 upsert: false))
        return path
    }

    func listDocuments() async -> [DocumentFile] {
        guard let client, let user = await currentUser() else { return [] }
        let folder = user.id.uuidString.lowercased()
        do {
            let files = try await client.storage.from("documents").list(path: folder)
            return files
                .filter { $0.name.hasSuffix(".pdf") }
                .map { file in
                    DocumentFile(path: "\(folder)/\(file.name)",
                                 displayName: Self.documentDisplayName(file.name),
                                 createdAt: file.createdAt)
                }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        } catch {
            AuthLog.warn("listDocuments", error)
            return []
        }
    }

    /// "1754800000-tahlil.pdf" → "tahlil.pdf". Epoch öneki yoksa ad aynen.
    static func documentDisplayName(_ name: String) -> String {
        let parts = name.split(separator: "-", maxSplits: 1)
        guard parts.count == 2, Int(parts[0]) != nil else { return name }
        return String(parts[1])
    }

    func downloadDocument(path: String) async -> Data? {
        guard let client else { return nil }
        return try? await client.storage.from("documents").download(path: path)
    }

    func deleteDocument(path: String) async throws {
        guard let client else { return }
        _ = try await client.storage.from("documents").remove(paths: [path])
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

    // MARK: Yemek fotoğrafı analizi (US-029)

    private struct AnalyzeResponse: Decodable {
        struct Item: Decodable {
            let name: String
            let matched: Bool
            let food_id: String?
            let grams: Int
            let kcal_100g: Int
            let portion_g: Int
            let portion_name: String
            let confidence: Double
        }
        let items: [Item]
        let note: String?
        let log_id: String?
        let used: Int?
        let quota: Int?
    }

    private struct AnalyzeError: Decodable {
        let error: String?
        let message: String?
    }

    enum MealAnalysisError: LocalizedError {
        case quota(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .quota(let text), .failed(let text): return text
            }
        }
    }

    /// Fotoğrafı Edge Function'a gönderip tahmini alır.
    ///
    /// Sağlayıcı anahtarı burada YOK — istek sunucuya gidiyor, sağlayıcıyı
    /// ve günlük kotayı sunucu belirliyor. Uygulamada bir hata olsa bile kota
    /// aşılamaz.
    func analyzeMeal(imageData: Data) async throws -> MealAnalysis {
        guard let client else {
            throw MealAnalysisError.failed("Sunucu bağlantısı yok.")
        }
        let body: [String: AnyJSON] = [
            "image": .string(imageData.base64EncodedString()),
            "mime": .string("image/jpeg")
        ]
        let response = try await client.functions.invoke(
            "analyze-meal",
            options: FunctionInvokeOptions(body: body)
        ) { data, urlResponse in
            (data, (urlResponse as? HTTPURLResponse)?.statusCode ?? 200)
        }

        let (data, status) = response
        guard status < 400 else {
            let detail = try? JSONDecoder().decode(AnalyzeError.self, from: data)
            let text = detail?.message ?? detail?.error ?? "Tahmin alınamadı."
            throw status == 429 ? MealAnalysisError.quota(text) : MealAnalysisError.failed(text)
        }

        let decoded = try JSONDecoder().decode(AnalyzeResponse.self, from: data)
        return MealAnalysis(
            items: decoded.items.map {
                AnalyzedFood(name: $0.name, foodID: $0.food_id, matched: $0.matched,
                             grams: $0.grams, kcal100: $0.kcal_100g,
                             portionG: $0.portion_g, portionName: $0.portion_name,
                             confidence: $0.confidence)
            },
            note: decoded.note,
            logID: decoded.log_id,
            usedToday: decoded.used ?? 0,
            quota: decoded.quota ?? 0)
    }

    private struct FoodRow: Decodable {
        let id: String
        let name: String
        let kcal_100g: Int
        let portion_g: Int
        let portion_name: String
    }

    /// Katalogda arama.
    ///
    /// Arama anahtarı sadeleştirilmiş sütunda tutuluyor; Türkçe'de
    /// `lowercased()` "İ" harfini "i" + birleşik nokta yapıyor ve hiçbir
    /// kayda eşleşmiyor (aynı tuzağa tartı OCR'ında da düşmüştük).
    /// 100 g başına kalori — porsiyon kalorisinden türetilir.
    static func kcalPer100(portionKcal: Int, portionG: Int) -> Int {
        Int((Double(portionKcal) * 100 / Double(max(1, portionG))).rounded())
    }

    /// Kullanıcının tanımladığı yiyecek (US-029 devamı): katalogda olmayan
    /// bir şeyi kullanıcı kendisi ekler. Katalog ORTAK olduğu için ekleme
    /// denetimli sunucu fonksiyonundan geçer (0029): küfür filtresi + AI
    /// "gerçek yiyecek mi / kalori makul mü" kontrolü + günlük kota.
    /// Uygun bulunmazsa fonksiyonun Türkçe gerekçesi hata olarak fırlatılır.
    func createFood(name: String, portionName: String, portionG: Int,
                    portionKcal: Int) async throws -> FoodOption? {
        guard let client else { return nil }
        let body: [String: AnyJSON] = [
            "name": .string(name),
            "portion_name": .string(portionName),
            "portion_g": .integer(portionG),
            "portion_kcal": .integer(portionKcal)
        ]
        let response = try await client.functions.invoke(
            "create-food",
            options: FunctionInvokeOptions(body: body)
        ) { data, urlResponse in
            (data, (urlResponse as? HTTPURLResponse)?.statusCode ?? 200)
        }
        let (data, status) = response

        struct Reply: Decodable {
            struct Food: Decodable {
                let id: String
                let name: String
                let kcal_100g: Int
                let portion_g: Int
                let portion_name: String
            }
            let food: Food?
            let error: String?
        }
        let decoded = try? JSONDecoder().decode(Reply.self, from: data)
        guard status < 400 else {
            throw MealAnalysisError.failed(decoded?.error ?? "Kaydedilemedi — tekrar dene.")
        }
        guard let food = decoded?.food else { return nil }
        return FoodOption(id: food.id, name: food.name, kcal100: food.kcal_100g,
                          portionG: food.portion_g, portionName: food.portion_name)
    }

    /// Hızlı ekle çipleri: anahtarları verilen yemekleri tek istekte getirir.
    func fetchFoods(searchKeys: [String]) async -> [FoodOption] {
        guard let client, !searchKeys.isEmpty else { return [] }
        do {
            let rows: [FoodRow] = try await client.from("foods")
                .select("id,name,kcal_100g,portion_g,portion_name")
                .in("search_key", values: searchKeys)
                .execute()
                .value
            return rows.map {
                FoodOption(id: $0.id, name: $0.name, kcal100: $0.kcal_100g,
                           portionG: $0.portion_g, portionName: $0.portion_name)
            }
        } catch {
            AuthLog.warn("fetchFoods", error)
            return []
        }
    }

    func searchFoods(_ query: String, limit: Int = 30) async -> [FoodOption] {
        guard let client else { return [] }
        let key = Self.searchKey(query)
        guard !key.isEmpty else { return [] }
        guard let rows: [FoodRow] = try? await client.from("foods")
            .select("id,name,kcal_100g,portion_g,portion_name")
            .ilike("search_key", pattern: "%\(key)%")
            .order("search_key")
            .limit(limit)
            .execute()
            .value else { return [] }
        return rows.map {
            FoodOption(id: $0.id, name: $0.name, kcal100: $0.kcal_100g,
                       portionG: $0.portion_g, portionName: $0.portion_name)
        }
    }

    /// Kullanıcının düzeltmesini kayda işler — doğruluğu ölçebilmek ve
    /// ileride kişiselleştirebilmek için. Fotoğraf saklanmıyor, yalnızca
    /// bu metin çifti.
    func recordMealCorrection(logID: String, finalItems: [AnalyzedFood],
                              corrected: Bool) async {
        guard let client else { return }
        let payload: [String: AnyJSON] = [
            "final_items": .array(finalItems.map {
                .object(["name": .string($0.name),
                         "grams": .integer($0.grams),
                         "kcal": .integer($0.kcal),
                         "matched": .bool($0.matched)])
            }),
            "corrected": .bool(corrected)
        ]
        guard let user = await currentUser() else { return }
        _ = try? await client.from("meal_photo_log")
            .update(payload)
            .eq("id", value: logID)
            .eq("user_id", value: user.id.uuidString)
            .execute()
    }

    /// Türkçe'ye özel sadeleştirme (sunucudaki `searchKey` ile aynı eşleme).
    static func searchKey(_ text: String) -> String {
        let map: [Character: Character] = [
            "İ": "i", "I": "i", "ı": "i", "Ş": "s", "ş": "s", "Ğ": "g", "ğ": "g",
            "Ü": "u", "ü": "u", "Ö": "o", "ö": "o", "Ç": "c", "ç": "c", "Â": "a", "â": "a"
        ]
        return String(text.map { map[$0] ?? $0 })
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Plan sihirbazı (US-030)

    /// Beslenme protokolleri. Katalog herkese açık okunur.
    func fetchProtocols() async -> [DietProtocol] {
        guard let client else { return [] }
        guard let rows: [DietProtocol] = try? await client.from("diet_protocols")
            .select("key,name,summary,evidence,evidence_note,source_url,carb_pct_min,carb_pct_max,fat_pct_min,fat_pct_max,protein_pct_min,protein_pct_max,protein_g_per_kg,favor_categories,limit_categories,avoid_categories,contraindications,needs_doctor,warning,phases")
            .order("sort_order")
            .execute()
            .value else { return [] }
        return rows
    }

    private struct PrefsRow: Decodable {
        let goal: String
        let protocol_key: String?
        let diet_style: String
        let allergies: [String]
        let dislikes: [String]
        let meals_per_day: Int
        let meal_times: [String]
        let eating_out_days: Int
        let workout_days: Int
        let equipment: String
        let injuries: [String]
        let health_flags: [String]
    }

    func fetchPlanPreferences() async -> PlanPreferences? {
        guard let client, let user = await currentUser() else { return nil }
        guard let rows: [PrefsRow] = try? await client.from("plan_preferences")
            .select("goal,protocol_key,diet_style,allergies,dislikes,meals_per_day,meal_times,eating_out_days,workout_days,equipment,injuries,health_flags")
            .eq("user_id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value,
            let row = rows.first else { return nil }

        var prefs = PlanPreferences()
        prefs.goal = PlanPreferences.Goal(rawValue: row.goal) ?? .lose
        prefs.protocolKey = row.protocol_key
        prefs.dietStyle = PlanPreferences.DietStyle(rawValue: row.diet_style) ?? .omnivore
        prefs.allergies = Set(row.allergies)
        prefs.dislikes = Set(row.dislikes)
        prefs.mealsPerDay = row.meals_per_day
        prefs.mealTimes = row.meal_times
        prefs.eatingOutDays = row.eating_out_days
        prefs.workoutDays = row.workout_days
        prefs.equipment = PlanPreferences.Equipment(rawValue: row.equipment) ?? .home
        prefs.injuries = Set(row.injuries)
        prefs.healthFlags = Set(row.health_flags)
        return prefs
    }

    func savePlanPreferences(_ prefs: PlanPreferences) async throws {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "goal": .string(prefs.goal.rawValue),
            "protocol_key": prefs.protocolKey.map { AnyJSON.string($0) } ?? .null,
            "diet_style": .string(prefs.dietStyle.rawValue),
            "allergies": .array(prefs.allergies.sorted().map { .string($0) }),
            "dislikes": .array(prefs.dislikes.sorted().map { .string($0) }),
            "meals_per_day": .integer(prefs.mealsPerDay),
            "meal_times": .array(prefs.mealTimes.map { .string($0) }),
            "eating_out_days": .integer(prefs.eatingOutDays),
            "workout_days": .integer(prefs.workoutDays),
            "equipment": .string(prefs.equipment.rawValue),
            "injuries": .array(prefs.injuries.sorted().map { .string($0) }),
            "health_flags": .array(prefs.healthFlags.sorted().map { .string($0) })
        ]
        try await client.from("plan_preferences")
            .upsert(payload, onConflict: "user_id")
            .execute()
    }

    // MARK: Kullanıcı antrenman programları (workout_programs, 0030)

    private struct ProgramRow: Codable {
        let id: String
        let name: String
        let region: String
        let level: String
        let items: [Exercise]
    }

    func fetchWorkoutPrograms() async -> [WorkoutProgram] {
        guard let client, let user = await currentUser() else { return [] }
        do {
            let rows: [ProgramRow] = try await client.from("workout_programs")
                .select("id,name,region,level,items")
                .eq("user_id", value: user.id.uuidString)
                .order("created_at")
                .execute()
                .value
            return rows.map {
                WorkoutProgram(id: UUID(uuidString: $0.id) ?? UUID(),
                               name: $0.name, region: $0.region,
                               level: $0.level, items: $0.items)
            }
        } catch {
            AuthLog.warn("fetchWorkoutPrograms", error)
            return []
        }
    }

    func saveWorkoutProgram(_ program: WorkoutProgram) async {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "id": .string(program.id.uuidString.lowercased()),
            "user_id": .string(user.id.uuidString.lowercased()),
            "name": .string(program.name),
            "region": .string(program.region),
            "level": .string(program.level),
            "items": Self.jsonbValue(program.items)
        ]
        do {
            try await client.from("workout_programs")
                .upsert(payload, onConflict: "id")
                .execute()
        } catch {
            AuthLog.warn("saveWorkoutProgram", error)
        }
    }

    func deleteWorkoutProgram(id: UUID) async {
        guard let client, let user = await currentUser() else { return }
        _ = try? await client.from("workout_programs")
            .delete()
            .eq("id", value: id.uuidString.lowercased())
            .eq("user_id", value: user.id.uuidString)
            .execute()
    }

    // MARK: Koç sohbeti (coach_state) — kişiye özel, RLS'li.
    //
    // Sohbet uygulama kapanınca sıfırlanıyordu. Yalnızca metin tabanlı
    // roller saklanır (user/coach/ask/planReady); eski demo kart rolleri
    // (plan/week/menu) codable yükler taşıdığı için elenir.

    struct StoredCoachMessage: Codable, Equatable {
        let role: String
        let text: String
        let title: String
        let options: [String]
    }

    static func storedMessages(from messages: [CoachMessage]) -> [StoredCoachMessage] {
        messages.compactMap { message in
            let role: String?
            switch message.role {
            case .user: role = "user"
            case .coach: role = "coach"
            case .ask: role = "ask"
            case .planReady: role = "planReady"
            case .plan, .week, .menu: role = nil
            }
            guard let role else { return nil }
            return StoredCoachMessage(role: role, text: message.text,
                                      title: message.title, options: message.options)
        }
        .suffix(200)
        .map { $0 }
    }

    static func coachMessages(from stored: [StoredCoachMessage]) -> [CoachMessage] {
        stored.map { row in
            let role: CoachRole
            switch row.role {
            case "user": role = .user
            case "ask": role = .ask
            case "planReady": role = .planReady
            default: role = .coach
            }
            return CoachMessage(role: role, text: row.text,
                                title: row.title, options: row.options)
        }
    }

    func fetchCoachMessages() async -> [CoachMessage]? {
        guard let client, let user = await currentUser() else { return nil }
        struct Row: Decodable { let messages: [StoredCoachMessage] }
        do {
            let rows: [Row] = try await client.from("coach_state")
                .select("messages")
                .eq("user_id", value: user.id.uuidString)
                .limit(1)
                .execute()
                .value
            guard let row = rows.first, !row.messages.isEmpty else { return nil }
            return Self.coachMessages(from: row.messages)
        } catch {
            AuthLog.warn("fetchCoachMessages", error)
            return nil
        }
    }

    func saveCoachMessages(_ messages: [CoachMessage]) async {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "messages": Self.jsonbValue(Self.storedMessages(from: messages)),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        do {
            try await client.from("coach_state")
                .upsert(payload, onConflict: "user_id")
                .execute()
        } catch {
            AuthLog.warn("saveCoachMessages", error)
        }
    }

    // MARK: Üretilen haftalık plan (plan_weeks) — kişiye özel, RLS'li.
    //
    // Plan yalnızca bellekte yaşıyordu: uygulama kapanınca kayboluyor,
    // sekmeler dolduramıyordu. Satır kullanıcı+hafta başına tek (unique),
    // RLS sayesinde kimse başkasının planını okuyamaz.

    private struct PlanWeekFetchRow: Decodable {
        let meals: WeekMealPlan?
        let workouts: WeekWorkoutPlan?

        enum CodingKeys: String, CodingKey { case meals, workouts }

        init(from decoder: Decoder) throws {
            // Kolon varsayılanı '[]'::jsonb — obje bekleyen çözümlemeyi
            // düşürmesin; bozuk/boş alan planı değil yalnızca o alanı yok sayar.
            let container = try decoder.container(keyedBy: CodingKeys.self)
            meals = try? container.decode(WeekMealPlan.self, forKey: .meals)
            workouts = try? container.decode(WeekWorkoutPlan.self, forKey: .workouts)
        }
    }

    /// Encodable değeri jsonb kolonuna yazılabilir AnyJSON'a çevirir.
    private static func jsonbValue<T: Encodable>(_ value: T?) -> AnyJSON {
        guard let value,
              let data = try? JSONEncoder().encode(value),
              let json = try? JSONDecoder().decode(AnyJSON.self, from: data)
        else { return .null }
        return json
    }

    func savePlanWeek(weekStart: Date, protocolKey: String?,
                      meals: WeekMealPlan?, workouts: WeekWorkoutPlan?) async {
        guard let client, let user = await currentUser() else { return }
        let payload: [String: AnyJSON] = [
            "user_id": .string(user.id.uuidString.lowercased()),
            "week_start": .string(Self.dayFormatter.string(from: weekStart)),
            "protocol_key": protocolKey.map { AnyJSON.string($0) } ?? .null,
            "kcal_target": .integer(meals?.kcalTarget ?? 0),
            "protein_g": meals.map { .integer($0.proteinTarget) } ?? .null,
            "carb_g": meals.map { .integer($0.carbTarget) } ?? .null,
            "fat_g": meals.map { .integer($0.fatTarget) } ?? .null,
            "meals": Self.jsonbValue(meals),
            "workouts": Self.jsonbValue(workouts)
        ]
        do {
            try await client.from("plan_weeks")
                .upsert(payload, onConflict: "user_id,week_start")
                .execute()
        } catch {
            AuthLog.warn("savePlanWeek", error)
        }
    }

    func fetchPlanWeek(weekStart: Date) async
        -> (meals: WeekMealPlan?, workouts: WeekWorkoutPlan?) {
        guard let client, let user = await currentUser() else { return (nil, nil) }
        do {
            let rows: [PlanWeekFetchRow] = try await client.from("plan_weeks")
                .select("meals,workouts")
                .eq("user_id", value: user.id.uuidString)
                .eq("week_start", value: Self.dayFormatter.string(from: weekStart))
                .limit(1)
                .execute()
                .value
            guard let row = rows.first else { return (nil, nil) }
            return (row.meals, row.workouts)
        } catch {
            AuthLog.warn("fetchPlanWeek", error)
            return (nil, nil)
        }
    }

    /// Plan üreticisi için tüm yemek kataloğu (225 satır — tek seferde).
    func fetchPlanFoods() async -> [PlanFood] {
        guard let client else { return [] }
        do {
            let rows: [PlanFood] = try await client.from("foods")
                .select("id,name,category,kcal_100g,protein_100g,carb_100g,fat_100g,portion_g,portion_name,tags,role")
                .limit(1000)
                .execute()
                .value
            return rows
        } catch {
            // Boş katalog = boş plan. Sessizce yutma; şema kayması anında görünsün.
            AuthLog.warn("fetchPlanFoods", error)
            return []
        }
    }

    /// Egzersiz havuzu — yalnızca kuvvet hareketleri gerekiyor ama filtre
    /// istemcide, çünkü sakatlık ve ekipman kuralları orada uygulanıyor.
    func fetchPlanExercises() async -> [PlanExercise] {
        guard let client else { return [] }
        guard let rows: [PlanExercise] = try? await client.from("exercises")
            .select("id,name,name_tr,region,equipment,needs,level,category,mechanic")
            .eq("category", value: "Kuvvet")
            .limit(2000)
            .execute()
            .value else { return [] }
        return rows
    }

    /// AI günlük plan üretimi (US-034).
    ///
    /// Sunucudan dönen planın `rule_check` beyanına GÜVENİLMEZ — çağıran
    /// taraf `PlanValidator` ile yeniden doğrular. Anahtar ve kota sunucuda.
    private struct GeneratedDayResponse: Decodable {
        let plan: DailyMealPlan
    }

    func generateMealPlanDay(inputJSON: String) async throws -> DailyMealPlan {
        guard let client else {
            throw MealAnalysisError.failed("Sunucu bağlantısı yok.")
        }
        let body: [String: AnyJSON] = ["input": .string(inputJSON)]
        let response = try await client.functions.invoke(
            "generate-meal-plan",
            options: FunctionInvokeOptions(body: body)
        ) { data, urlResponse in
            (data, (urlResponse as? HTTPURLResponse)?.statusCode ?? 200)
        }
        let (data, status) = response
        guard status < 400 else {
            let detail = try? JSONDecoder().decode(AnalyzeError.self, from: data)
            let text = detail?.message ?? detail?.error ?? "Plan üretilemedi."
            throw status == 429 ? MealAnalysisError.quota(text) : MealAnalysisError.failed(text)
        }
        return try JSONDecoder().decode(GeneratedDayResponse.self, from: data).plan
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

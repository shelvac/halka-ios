import Foundation

// MARK: - Profil yükleme / kaydetme (US-016)

extension AppModel {

    /// Oturum açıldıktan sonra profili buluttan çeker.
    /// Sessiz çalışır: profil yoksa ya da ağ hatası olursa uygulama varsayılan
    /// hedeflerle devam eder, kullanıcıya hata gösterilmez.
    func loadProfile() async {
        guard supabaseReady else { return }
        guard let loaded = await SupabaseService.shared.fetchProfile() else { return }
        profile = loaded
        if !loaded.fullName.isEmpty {
            applyFullName(loaded.fullName)
        }
    }

    /// Profil düzenleme ekranından kaydeder.
    /// Başarısızsa yerel değişiklik geri alınır — ekranda kaydedilmiş görünüp
    /// sunucuda olmaması en kötü sonuç olurdu.
    @discardableResult
    func saveProfile(_ updated: Profile) async -> Bool {
        profileError = nil
        let previous = profile
        profile = updated
        if !updated.fullName.isEmpty {
            applyFullName(updated.fullName)
        }

        guard supabaseReady else { return true }   // demo modu: yerelde kalır

        profileBusy = true
        defer { profileBusy = false }
        do {
            try await SupabaseService.shared.saveProfile(updated)
            return true
        } catch {
            profile = previous
            profileError = "Profil kaydedilemedi — bağlantını kontrol edip tekrar dene."
            AuthLog.warn("saveProfile", error)
            return false
        }
    }

    /// Profil kartında gösterilecek özet: "31 yaş · Kadın · 04.02.1995".
    /// Eksik alanlar atlanır; hiçbiri yoksa kullanıcıyı doldurmaya çağırır.
    var profileSummary: String {
        var parts: [String] = []
        if let age = profile.age { parts.append("\(age) yaş") }
        if let sex = profile.sex { parts.append(sex.label) }
        if let birth = profile.birthDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "tr_TR")
            f.dateFormat = "dd.MM.yyyy"
            parts.append(f.string(from: birth))
        }
        return parts.isEmpty ? "Profilini tamamla" : parts.joined(separator: " · ")
    }
}

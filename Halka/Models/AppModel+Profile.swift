import Foundation
import UIKit

// MARK: - Profil yükleme / kaydetme (US-016)

extension AppModel {

    /// Oturum açıldıktan sonra profili buluttan çeker.
    /// Sessiz çalışır: profil yoksa ya da ağ hatası olursa uygulama varsayılan
    /// hedeflerle devam eder, kullanıcıya hata gösterilmez.
    func loadProfile() async {
        guard supabaseReady else { return }
        var fetched = await SupabaseService.shared.fetchProfile()
        if fetched == nil {
            // Tek seferlik geçici ağ hatası profili "boş" göstermesin —
            // kullanıcı verisinin uçtuğunu sanıyor. Bir kez daha dene.
            try? await Task.sleep(for: .seconds(1))
            fetched = await SupabaseService.shared.fetchProfile()
        }
        guard let loaded = fetched else { return }
        profile = loaded
        if !loaded.fullName.isEmpty {
            applyFullName(loaded.fullName)
        }
        if let path = loaded.avatarPath,
           let data = await SupabaseService.shared.downloadAvatar(path: path) {
            avatarImage = UIImage(data: data)
        }
    }

    /// Galeriden seçilen fotoğrafı küçültüp yükler.
    ///
    /// Önce yerelde gösterilir (kullanıcı beklemesin), sonra yüklenir; yükleme
    /// düşerse eski fotoğrafa dönülür — ekranda değişmiş görünüp sunucuda
    /// olmaması yanıltıcı olurdu.
    func updateAvatar(_ image: UIImage) async {
        profileError = nil
        let previous = avatarImage
        avatarImage = image

        guard supabaseReady, let data = Self.avatarJPEG(image) else { return }

        profileBusy = true
        defer { profileBusy = false }
        do {
            let path = try await SupabaseService.shared.uploadAvatar(data)
            profile.avatarPath = path
        } catch {
            avatarImage = previous
            profileError = "Fotoğraf yüklenemedi — bağlantını kontrol edip tekrar dene."
            AuthLog.warn("uploadAvatar", error)
        }
    }

    func removeAvatar() async {
        let previous = avatarImage
        avatarImage = nil
        guard supabaseReady else { return }
        do {
            try await SupabaseService.shared.removeAvatar()
            profile.avatarPath = nil
        } catch {
            avatarImage = previous
            profileError = "Fotoğraf kaldırılamadı — tekrar dene."
            AuthLog.warn("removeAvatar", error)
        }
    }

    /// Avatarı 512 pikselde JPEG'e çevirir — telefondan gelen 4-5 MB'lık kareyi
    /// olduğu gibi yüklemek hem yavaş hem gereksiz.
    private static func avatarJPEG(_ image: UIImage, maxSide: CGFloat = 512) -> Data? {
        let side = max(image.size.width, image.size.height)
        let scale = side > maxSide ? maxSide / side : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
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

    /// Sağlık verisi açık rızasını geri çeker (KVKK m.6).
    ///
    /// Rıza olmadan sağlık takibi hukuki dayanağını kaybeder; bu yüzden geri
    /// çekme sonrası oturum kapatılır. Kullanıcı tekrar girip rıza verirse
    /// devam edebilir, vermezse hesabını silebilir.
    @discardableResult
    func withdrawHealthConsent() async -> Bool {
        profileError = nil
        guard supabaseReady else { return true }
        profileBusy = true
        defer { profileBusy = false }
        do {
            try await SupabaseService.shared.withdrawHealthConsent()
            profile.healthConsentAt = nil
            logout()
            authInfo = "Açık rızan geri çekildi. Sağlık takibi için tekrar rıza vermen gerekiyor."
            return true
        } catch {
            profileError = "Rıza geri çekilemedi — bağlantını kontrol edip tekrar dene."
            AuthLog.warn("withdrawConsent", error)
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

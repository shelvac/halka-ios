import Foundation

/// US-016 — Kullanıcı profili ve ondan türeyen kişiye özel hedefler.
///
/// Şimdiye kadar halka hedefleri sabitti (60 dk · 2000 ml · 8 sa · 1420 kcal).
/// 25 yaşında 90 kilo bir erkekle 60 yaşında 50 kilo bir kadına aynı kalori
/// hedefini vermek anlamsız; bu tip profili gerçek veriye bağlar ve hedefleri
/// ondan hesaplar.
struct Profile: Codable, Equatable {
    var fullName: String = ""
    /// `avatars` bucket'ındaki dosya yolu; boşsa baş harf avatarı gösterilir.
    var avatarPath: String?
    var birthDate: Date?
    var sex: Sex?
    var heightCm: Double?
    var weightKg: Double?
    var targetWeightKg: Double?
    var activityLevel: ActivityLevel?
    var completedAt: Date?
    /// KVKK aydınlatma onayı ve sağlık verisi AÇIK RIZA zaman damgaları.
    /// Rıza geri çekilince `healthConsentAt` boşalır (KVKK m.6).
    var kvkkAcceptedAt: Date?
    var healthConsentAt: Date?

    /// Sağlık verisi işlemeye rıza var mı?
    var hasHealthConsent: Bool { healthConsentAt != nil }

    enum Sex: String, Codable, CaseIterable, Identifiable {
        case female, male, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .female: return "Kadın"
            case .male: return "Erkek"
            case .other: return "Belirtmek istemiyorum"
            }
        }
    }

    /// TDEE çarpanları — Mifflin-St Jeor ile birlikte kullanılan yaygın katsayılar.
    enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
        case sedentary, light, moderate, active, veryActive = "very_active"
        var id: String { rawValue }

        var label: String {
            switch self {
            case .sedentary: return "Hareketsiz"
            case .light: return "Az hareketli"
            case .moderate: return "Orta"
            case .active: return "Hareketli"
            case .veryActive: return "Çok hareketli"
            }
        }

        var detail: String {
            switch self {
            case .sedentary: return "Masa başı, düzenli spor yok"
            case .light: return "Haftada 1-3 gün hafif egzersiz"
            case .moderate: return "Haftada 3-5 gün egzersiz"
            case .active: return "Haftada 6-7 gün egzersiz"
            case .veryActive: return "Ağır fiziksel iş veya günde iki antrenman"
            }
        }

        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .light: return 1.375
            case .moderate: return 1.55
            case .active: return 1.725
            case .veryActive: return 1.9
            }
        }
    }

    // MARK: Türetilen değerler

    var age: Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    /// Hedef hesabı için gereken asgari veri girildi mi?
    var isComplete: Bool {
        birthDate != nil && sex != nil && heightCm != nil && weightKg != nil
    }

    var bmi: Double? {
        guard let heightCm, let weightKg, heightCm > 0 else { return nil }
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    var bmiLabel: String? {
        guard let bmi else { return nil }
        switch bmi {
        case ..<18.5: return "Zayıf"
        case ..<25: return "Normal"
        case ..<30: return "Fazla kilolu"
        default: return "Obez"
        }
    }

    /// Bazal metabolizma hızı — Mifflin-St Jeor (1990).
    /// Kadın/erkek dışındaki seçimlerde iki formülün ortalaması kullanılır;
    /// klinik bir karşılığı yok ama sistematik sapmayı azaltır.
    var bmr: Double? {
        guard let weightKg, let heightCm, let age, let sex else { return nil }
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        case .other: return base - 78
        }
    }

    /// Günlük toplam enerji harcaması.
    var tdee: Double? {
        guard let bmr else { return nil }
        return bmr * (activityLevel ?? .light).multiplier
    }

    /// Günlük kalori hedefi.
    ///
    /// Kilo vermek isteyene ~%15 açık verilir (haftada ~0,5 kg). Güvenlik
    /// tabanı var: hedef, BMR'nin altına indirilmez — agresif açık hem sağlıksız
    /// hem sürdürülemez, uygulama bunu önermemeli.
    var calorieGoal: Int? {
        guard let tdee, let bmr else { return nil }
        guard let target = targetWeightKg, let current = weightKg else {
            return Int(tdee.rounded())
        }
        let raw: Double
        if target < current - 0.5 {
            raw = max(tdee * 0.85, bmr)          // kilo verme
        } else if target > current + 0.5 {
            raw = tdee * 1.1                      // kilo alma
        } else {
            raw = tdee                            // koruma
        }
        return Int((raw / 10).rounded() * 10)     // 10'a yuvarla
    }

    /// Günlük su hedefi (ml) — kilo başına ~33 ml.
    ///
    /// Taban 2000 ml: hesap daha azını önerse bile (düşük kilo) günlük 2 litre
    /// yaygın kabul gören asgari öneri, altını hedef olarak göstermiyoruz.
    /// Tavan 4000 ml — üstü kişiye özel tıbbi değerlendirme ister.
    var waterGoalML: Int? {
        guard let weightKg else { return nil }
        let raw = weightKg * 33
        return Int((min(max(raw, 2000), 4000) / 50).rounded() * 50)
    }

    /// Haftalık 150 dk orta şiddet önerisinin günlük karşılığı (DSÖ);
    /// hareket düzeyi yükseldikçe hedef de yükselir.
    var exerciseGoalMin: Int {
        switch activityLevel ?? .light {
        case .sedentary, .light: return 30
        case .moderate: return 45
        case .active: return 60
        case .veryActive: return 75
        }
    }

    /// Günlük adım hedefi — hareket düzeyine göre.
    /// 10.000 yaygın bir varsayılan ama herkese uygun değil; hareketsiz biri
    /// için ulaşılamaz hedef motive etmez, çok hareketli biri için fazla kolay.
    var stepsGoal: Int {
        switch activityLevel ?? .light {
        case .sedentary: return 6000
        case .light: return 8000
        case .moderate: return 10000
        case .active: return 12000
        case .veryActive: return 14000
        }
    }

    /// Uyku hedefi — yetişkinlerde 7-9 saat; 65 yaş üstünde 7-8.
    /// Halka değil, istatistik olarak gösterilir.
    var sleepGoalHours: Double {
        guard let age else { return 8 }
        return age >= 65 ? 7.5 : 8
    }
}

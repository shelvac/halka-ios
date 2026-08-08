import Foundation

// MARK: - Plan sihirbazı ve beslenme protokolleri (US-030)

/// Bir beslenme protokolü — makro hedefleri, kısıtları ve **kanıt düzeyi**.
///
/// Kanıt düzeyi görünür bir alan: Dukan ile Akdeniz aynı güvenle sunulamaz.
/// Kullanıcı neyin neye dayandığını görmeden seçim yapmamalı.
struct DietProtocol: Identifiable, Equatable, Decodable {
    let key: String
    let name: String
    let summary: String
    /// güçlü · orta · zayıf · gelişmekte
    let evidence: String
    let evidenceNote: String?
    let sourceURL: String?

    let carbMin: Int?, carbMax: Int?
    let fatMin: Int?, fatMax: Int?
    let proteinMin: Int?, proteinMax: Int?
    /// Verilmişse yüzde yerine bu kullanılır (kg başına gram).
    let proteinPerKg: Double?

    let favorCategories: [String]
    let limitCategories: [String]
    let avoidCategories: [String]
    /// Kullanıcıda bu bayraklardan biri varsa protokol hiç gösterilmez.
    let contraindications: [String]
    let needsDoctor: Bool
    let warning: String?
    let phases: [Phase]?

    var id: String { key }

    struct Phase: Equatable, Decodable {
        let ad: String
        let sure: String
        let aciklama: String
    }

    /// Ortalama makro yüzdeleri — önizlemede gram hesabı için.
    var carbPct: Double { Self.mid(carbMin, carbMax) ?? 45 }
    var fatPct: Double { Self.mid(fatMin, fatMax) ?? 30 }
    var proteinPct: Double { Self.mid(proteinMin, proteinMax) ?? 20 }

    private static func mid(_ a: Int?, _ b: Int?) -> Double? {
        guard let a, let b else { return a.map(Double.init) ?? b.map(Double.init) }
        return Double(a + b) / 2
    }

    /// Hedef kaloriden ve kilodan makro gramlarını hesaplar.
    ///
    /// Protein g/kg verilmişse önce o ayrılır, kalan enerji karbonhidrat ve
    /// yağ arasında protokolün oranıyla paylaştırılır — yüzdeyi körü körüne
    /// uygulamak, kilosu düşük birine yetersiz protein verirdi.
    func macros(kcal: Int, weightKg: Double?) -> (protein: Int, carb: Int, fat: Int) {
        let total = Double(kcal)
        if let perKg = proteinPerKg, let weight = weightKg, weight > 0 {
            let proteinG = perKg * weight
            let remaining = max(total - proteinG * 4, 0)
            let ratio = carbPct + fatPct
            let carbKcal = ratio > 0 ? remaining * (carbPct / ratio) : remaining / 2
            let fatKcal = remaining - carbKcal
            return (Int(proteinG.rounded()),
                    Int((carbKcal / 4).rounded()),
                    Int((fatKcal / 9).rounded()))
        }
        return (Int((total * proteinPct / 100 / 4).rounded()),
                Int((total * carbPct / 100 / 4).rounded()),
                Int((total * fatPct / 100 / 9).rounded()))
    }

    enum CodingKeys: String, CodingKey {
        case key, name, summary, evidence
        case evidenceNote = "evidence_note"
        case sourceURL = "source_url"
        case carbMin = "carb_pct_min", carbMax = "carb_pct_max"
        case fatMin = "fat_pct_min", fatMax = "fat_pct_max"
        case proteinMin = "protein_pct_min", proteinMax = "protein_pct_max"
        case proteinPerKg = "protein_g_per_kg"
        case favorCategories = "favor_categories"
        case limitCategories = "limit_categories"
        case avoidCategories = "avoid_categories"
        case contraindications
        case needsDoctor = "needs_doctor"
        case warning, phases
    }
}

/// Sihirbazın topladığı yanıtlar.
struct PlanPreferences: Equatable {
    var goal: Goal = .lose
    var protocolKey: String?
    var dietStyle: DietStyle = .omnivore
    var allergies: Set<String> = []
    var dislikes: Set<String> = []
    var mealsPerDay: Int = 4
    var mealTimes: [String] = ["08:30", "13:00", "16:30", "20:00"]
    var eatingOutDays: Int = 0
    var workoutDays: Int = 3
    var equipment: Equipment = .home
    var injuries: Set<String> = []
    var healthFlags: Set<String> = []

    enum Goal: String, CaseIterable, Identifiable {
        case lose, maintain, gain
        var id: String { rawValue }
        var label: String {
            switch self {
            case .lose: return "Kilo vermek"
            case .maintain: return "Korumak"
            case .gain: return "Kas kazanmak"
            }
        }
        var detail: String {
            switch self {
            case .lose: return "Kalori açığı, kas koruyarak"
            case .maintain: return "Dengede kal, formu koru"
            case .gain: return "Hafif kalori fazlası + kuvvet"
            }
        }
    }

    enum DietStyle: String, CaseIterable, Identifiable {
        case omnivore, vegetarian, vegan
        var id: String { rawValue }
        var label: String {
            switch self {
            case .omnivore: return "Hepçil"
            case .vegetarian: return "Vejetaryen"
            case .vegan: return "Vegan"
            }
        }
    }

    enum Equipment: String, CaseIterable, Identifiable {
        case none, home, gym
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "Ekipmansız"
            case .home: return "Evde (dumbbell, band)"
            case .gym: return "Salon"
            }
        }
        var detail: String {
            switch self {
            case .none: return "Sadece vücut ağırlığı"
            case .home: return "Küçük ekipmanlar var"
            case .gym: return "Tam ekipman erişimi"
            }
        }
    }

    /// Sağlık taraması seçenekleri — anahtar, protokollerin
    /// `contraindications` listesiyle birebir eşleşiyor.
    static let healthOptions: [(key: String, label: String)] = [
        ("gebelik", "Gebelik"),
        ("emzirme", "Emzirme"),
        ("bobrek", "Böbrek hastalığı"),
        ("karaciger", "Karaciğer hastalığı"),
        ("diyabet_ilac", "Diyabet (ilaç kullanıyorum)"),
        ("tansiyon", "Yüksek tansiyon"),
        ("kalp", "Kalp hastalığı"),
        ("gut", "Gut"),
        ("tiroid", "Tiroid"),
        ("yeme_bozuklugu", "Yeme bozukluğu geçmişi")
    ]

    static let allergyOptions = ["Gluten", "Laktoz", "Yumurta", "Balık",
                                 "Kabuklu deniz ürünü", "Fındık/ceviz", "Soya", "Susam"]

    static let dislikeOptions = ["Kırmızı et", "Balık", "Süt ürünleri", "Baklagil",
                                 "Acı", "Sakatat", "Mantar", "Zeytin"]

    static let injuryOptions = ["Diz", "Bel", "Omuz", "Boyun", "Bilek", "Ayak bileği"]

    /// Sakatlıkların dışladığı egzersiz bölgeleri.
    static let injuryBlocks: [String: [String]] = [
        "Diz": ["Ön Bacak", "Arka Bacak"],
        "Bel": ["Bel"],
        "Omuz": ["Omuz"],
        "Boyun": ["Boyun", "Trapez"],
        "Bilek": ["Ön Kol"],
        "Ayak bileği": ["Baldır"]
    ]
}

/// Sihirbaz adımları.
enum PlanWizardStep: Int, CaseIterable {
    case goal, health, diet, food, meals, workout, review

    var title: String {
        switch self {
        case .goal: return "Hedefin ne?"
        case .health: return "Sağlık durumun"
        case .diet: return "Beslenme düzeni"
        case .food: return "Yemek tercihlerin"
        case .meals: return "Öğün düzenin"
        case .workout: return "Antrenman"
        case .review: return "Özet"
        }
    }

    var subtitle: String {
        switch self {
        case .goal: return "Planın tamamı buna göre kurulur."
        case .health: return "Sana uygun olmayan düzenleri hiç göstermemek için soruyoruz. Hiçbiri yoksa boş geç."
        case .diet: return "Yalnızca sana uygun olanlar listeleniyor."
        case .food: return "Sevmediğin ve yiyemediğin şeyler plana girmesin."
        case .meals: return "Günde kaç öğün, hangi saatlerde?"
        case .workout: return "Haftada kaç gün ve neyle?"
        case .review: return "Her şey doğru mu?"
        }
    }
}

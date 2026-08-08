import Foundation

// MARK: - Fotoğraftan öğün tahmini (US-029)

/// Fotoğrafta tespit edilen tek bir yiyecek.
///
/// Kalori **AI'dan değil**, `foods` kataloğundan geliyor: aynı yemeğe her
/// çağrıda farklı sayı vermesi tutarsızlık üretirdi. Katalogda eşleşme yoksa
/// AI'ın kendi tahmini kullanılıyor ve `matched = false` ile işaretleniyor —
/// kullanıcı hangi sayının nereden geldiğini bilsin.
struct AnalyzedFood: Identifiable, Equatable {
    let id: UUID
    var name: String
    var foodID: String?
    /// Katalogda karşılığı bulundu mu?
    var matched: Bool
    var grams: Int
    /// 100 gram başına kalori — porsiyon değişince hesap buradan yapılır.
    var kcal100: Int
    var portionG: Int
    var portionName: String
    /// AI'ın tanımaya güveni (0-1). Düşükse arayüz bunu söylüyor.
    var confidence: Double

    init(id: UUID = UUID(), name: String, foodID: String? = nil, matched: Bool,
         grams: Int, kcal100: Int, portionG: Int, portionName: String,
         confidence: Double) {
        self.id = id
        self.name = name
        self.foodID = foodID
        self.matched = matched
        self.grams = max(1, grams)
        self.kcal100 = max(0, kcal100)
        self.portionG = max(1, portionG)
        self.portionName = portionName
        self.confidence = min(1, max(0, confidence))
    }

    var kcal: Int { Int((Double(kcal100) * Double(grams) / 100).rounded()) }

    /// Porsiyon çarpanı — 150 g'lık porsiyonda 225 g ise 1,5.
    var portionMultiple: Double { Double(grams) / Double(portionG) }

    /// "1½ porsiyon · 225 g"
    var portionText: String {
        let m = portionMultiple
        let label: String
        switch m {
        case ..<0.38: label = "¼"
        case ..<0.63: label = "½"
        case ..<0.88: label = "¾"
        case ..<1.13: label = "1"
        case ..<1.38: label = "1¼"
        case ..<1.63: label = "1½"
        case ..<2.25: label = "2"
        default: label = String(format: "%.1f", m).replacingOccurrences(of: ".", with: ",")
        }
        return "\(label) \(portionName) · \(grams) g"
    }

    /// Porsiyon seçicisindeki hazır adımlar.
    static let steps: [Double] = [0.5, 1, 1.5, 2]

    static func stepLabel(_ value: Double) -> String {
        switch value {
        case 0.5: return "½"
        case 1: return "1"
        case 1.5: return "1½"
        default: return "2"
        }
    }
}

/// Sunucudan dönen tahmin.
struct MealAnalysis: Equatable {
    var items: [AnalyzedFood]
    var note: String?
    /// Öğrenme kaydının kimliği — kullanıcı düzeltmesi buna bağlanır.
    var logID: String?
    var usedToday: Int
    var quota: Int

    var totalKcal: Int { items.reduce(0) { $0 + $1.kcal } }

    /// Ölçüm belirsizliği ±%15: porsiyon tahmini fotoğraftan yapılıyor ve
    /// tek bir sayı bu belirsizliği gizlerdi.
    var kcalRange: (low: Int, high: Int) {
        let total = Double(totalKcal)
        return (Int((total * 0.85).rounded()), Int((total * 1.15).rounded()))
    }

    /// En düşük güven — başlıkta "emin değil" uyarısı için.
    var lowestConfidence: Double { items.map(\.confidence).min() ?? 1 }
}

/// Katalog araması sonucu.
struct FoodOption: Identifiable, Equatable {
    let id: String
    let name: String
    let kcal100: Int
    let portionG: Int
    let portionName: String

    /// Bir porsiyonun kalorisi — arama listesinde gösterilir.
    var portionKcal: Int { Int((Double(kcal100) * Double(portionG) / 100).rounded()) }
}

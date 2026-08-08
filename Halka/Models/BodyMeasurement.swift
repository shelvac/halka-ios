import Foundation

/// US-025 — Akıllı tartıdan gelen tek bir tartım.
///
/// Bütün ölçüler opsiyonel: basit bir tartı yalnızca kiloyu verir, eksik alanı
/// sıfır yazmak veriyi bozar ("yağ oranın %0" demek gibi).
struct BodyMeasurement: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var measuredAt: Date

    var weightKg: Double?
    var bmi: Double?
    var fatPercent: Double?
    var fatMassKg: Double?
    var skeletalMusclePercent: Double?
    var skeletalMuscleKg: Double?
    var musclePercent: Double?
    var muscleMassKg: Double?
    var visceralFat: Double?
    var waterPercent: Double?
    var waterMassKg: Double?
    var bmrKcal: Int?
    var obesityPercent: Double?
    var boneMassKg: Double?
    var proteinPercent: Double?
    var leanMassKg: Double?
    var metabolicAge: Int?

    var source: Source = .manual
    var photoPath: String?

    enum Source: String, Codable { case photo, manual }

    /// Hiç değer okunamadıysa kaydetmenin anlamı yok.
    var isEmpty: Bool { fields.allSatisfy { $0.value == nil } }

    // MARK: Alan tanımları
    //
    // Tek bir listede tanımlanıyor: ekranda gösterim, karşılaştırma ve
    // fotoğraftan okuma aynı sırayı ve aynı adları kullansın.

    struct Field: Identifiable {
        let id: String
        let label: String
        let unit: String
        /// Değerin artması iyi mi? Karşılaştırmada rengi belirler.
        /// `nil` → nötr (yorum yapmıyoruz).
        let higherIsBetter: Bool?
        let value: Double?
        /// Ondalık gösterilsin mi (metabolizma ve metabolik yaş tam sayı).
        let decimals: Int
    }

    var fields: [Field] {
        [
            Field(id: "weight", label: "Ağırlık", unit: "kg", higherIsBetter: nil,
                  value: weightKg, decimals: 2),
            Field(id: "bmi", label: "BMI", unit: "", higherIsBetter: nil,
                  value: bmi, decimals: 1),
            Field(id: "fatPercent", label: "Yağ", unit: "%", higherIsBetter: false,
                  value: fatPercent, decimals: 1),
            Field(id: "fatMass", label: "Vücut Yağ Ağırlığı", unit: "kg", higherIsBetter: false,
                  value: fatMassKg, decimals: 2),
            Field(id: "skeletalMusclePercent", label: "İskelet Kası Kütlesi", unit: "%",
                  higherIsBetter: true, value: skeletalMusclePercent, decimals: 1),
            Field(id: "skeletalMuscleKg", label: "İskelet Kası Ağırlığı", unit: "kg",
                  higherIsBetter: true, value: skeletalMuscleKg, decimals: 2),
            Field(id: "musclePercent", label: "Kas", unit: "%", higherIsBetter: true,
                  value: musclePercent, decimals: 1),
            Field(id: "muscleMass", label: "Kas Ağırlığı", unit: "kg", higherIsBetter: true,
                  value: muscleMassKg, decimals: 2),
            Field(id: "visceralFat", label: "Viseral Yağ", unit: "", higherIsBetter: false,
                  value: visceralFat, decimals: 1),
            Field(id: "waterPercent", label: "Su", unit: "%", higherIsBetter: true,
                  value: waterPercent, decimals: 1),
            Field(id: "waterMass", label: "Vücut Sıvı Ağırlığı", unit: "kg", higherIsBetter: true,
                  value: waterMassKg, decimals: 2),
            Field(id: "bmr", label: "Metabolizma", unit: "kcal/gün", higherIsBetter: true,
                  value: bmrKcal.map(Double.init), decimals: 0),
            Field(id: "obesity", label: "Obezite Derecesi", unit: "%", higherIsBetter: false,
                  value: obesityPercent, decimals: 1),
            Field(id: "boneMass", label: "Kemik Kütlesi", unit: "kg", higherIsBetter: nil,
                  value: boneMassKg, decimals: 2),
            Field(id: "protein", label: "Protein", unit: "%", higherIsBetter: true,
                  value: proteinPercent, decimals: 1),
            Field(id: "leanMass", label: "Yağsız Vücut Ağırlığı", unit: "kg",
                  higherIsBetter: true, value: leanMassKg, decimals: 2),
            Field(id: "metabolicAge", label: "Metabolik Yaş", unit: "", higherIsBetter: false,
                  value: metabolicAge.map(Double.init), decimals: 0)
        ]
    }

    /// Alanı kimliğiyle günceller (düzenleme ekranı bunu kullanır).
    mutating func setValue(_ value: Double?, forField id: String) {
        switch id {
        case "weight": weightKg = value
        case "bmi": bmi = value
        case "fatPercent": fatPercent = value
        case "fatMass": fatMassKg = value
        case "skeletalMusclePercent": skeletalMusclePercent = value
        case "skeletalMuscleKg": skeletalMuscleKg = value
        case "musclePercent": musclePercent = value
        case "muscleMass": muscleMassKg = value
        case "visceralFat": visceralFat = value
        case "waterPercent": waterPercent = value
        case "waterMass": waterMassKg = value
        case "bmr": bmrKcal = value.map { Int($0.rounded()) }
        case "obesity": obesityPercent = value
        case "boneMass": boneMassKg = value
        case "protein": proteinPercent = value
        case "leanMass": leanMassKg = value
        case "metabolicAge": metabolicAge = value.map { Int($0.rounded()) }
        default: break
        }
    }

    // MARK: Karşılaştırma

    /// Bir önceki ölçüme göre değişim. Önceki değer yoksa `nil`.
    struct Delta {
        let amount: Double
        /// Bu değişim iyiye mi gidiyor? Nötr alanlarda `nil`.
        let isImprovement: Bool?

        var isFlat: Bool { abs(amount) < 0.005 }
    }

    func delta(forField id: String, since previous: BodyMeasurement?) -> Delta? {
        guard let previous,
              let current = fields.first(where: { $0.id == id })?.value,
              let old = previous.fields.first(where: { $0.id == id })?.value else { return nil }
        let change = current - old
        let field = fields.first { $0.id == id }
        let improvement: Bool?
        if let higherIsBetter = field?.higherIsBetter, abs(change) >= 0.005 {
            improvement = (change > 0) == higherIsBetter
        } else {
            improvement = nil
        }
        return Delta(amount: change, isImprovement: improvement)
    }
}

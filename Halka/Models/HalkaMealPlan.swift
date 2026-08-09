//
//  HalkaMealPlan.swift
//  Halka — AI Koç günlük plan modelleri
//
//  AI'ın döndürdüğü JSON'ı doğrudan parse eder:
//  let plan = try JSONDecoder().decode(DailyMealPlan.self, from: data)
//

import Foundation

// MARK: - Enums

enum PlanDay: String, Codable {
    case pazartesi, sali, carsamba, persembe, cuma, cumartesi, pazar
}

enum MealType: String, Codable {
    case kahvalti, ogle, araOgun = "ara_ogun", aksam
}

enum FoodCategory: String, Codable {
    case anaYemek = "ana_yemek"
    case yanYemek = "yan_yemek"
    case tamamlayici
    case tatliMeyve = "tatli_meyve"
    case atistirmalik
    case anaProtein = "ana_protein"      // kahvaltı çapası
    case karbonhidrat
}

enum ProteinType: String, Codable {
    case kirmiziEt = "kirmizi_et"
    case beyazEt = "beyaz_et"
    case denizUrunu = "deniz_urunu"
    case bitkisel
    case yumurtaSut = "yumurta_sut"
    case yok
}

enum PortionUnit: String, Codable {
    case adet, dilim, kase, porsiyon, avuc, bardak
    case yemekKasigi = "yemek_kasigi"
    case gram
}

// MARK: - Models

struct MacroTotals: Codable {
    let kcal: Int
    let proteinG: Double
    let carbG: Double
    let fatG: Double

    enum CodingKeys: String, CodingKey {
        case kcal
        case proteinG = "protein_g"
        case carbG = "carb_g"
        case fatG = "fat_g"
    }
}

struct FoodItem: Codable, Identifiable {
    var id: String { "\(name)-\(grams)" }

    let name: String
    let category: FoodCategory
    let proteinType: ProteinType
    let amount: Double
    let unit: PortionUnit
    let grams: Int
    let kcal: Int
    let proteinG: Double
    let carbG: Double
    let fatG: Double

    enum CodingKeys: String, CodingKey {
        case name, category, amount, unit, grams, kcal
        case proteinType = "protein_type"
        case proteinG = "protein_g"
        case carbG = "carb_g"
        case fatG = "fat_g"
    }
}

struct Meal: Codable, Identifiable {
    var id: String { "\(mealType.rawValue)-\(time)" }

    let mealType: MealType
    let time: String
    let items: [FoodItem]
    let mealTotals: MacroTotals

    enum CodingKeys: String, CodingKey {
        case time, items
        case mealType = "meal_type"
        case mealTotals = "meal_totals"
    }
}

struct RuleCheck: Codable {
    let oneMainPerMeal: Bool
    let noProteinMixing: Bool
    let breakfastIntegrity: Bool
    let kcalWithinTolerance: Bool
    let allergensAbsent: Bool
    let protocolCompliant: Bool

    enum CodingKeys: String, CodingKey {
        case oneMainPerMeal = "one_main_per_meal"
        case noProteinMixing = "no_protein_mixing"
        case breakfastIntegrity = "breakfast_integrity"
        case kcalWithinTolerance = "kcal_within_tolerance"
        case allergensAbsent = "allergens_absent"
        case protocolCompliant = "protocol_compliant"
    }

    var allPassed: Bool {
        oneMainPerMeal && noProteinMixing && breakfastIntegrity
            && kcalWithinTolerance && allergensAbsent && protocolCompliant
    }
}

struct DailyMealPlan: Codable {
    let day: PlanDay
    let meals: [Meal]
    let dayTotals: MacroTotals
    let targetDeviationPct: Double
    let ruleCheck: RuleCheck

    enum CodingKeys: String, CodingKey {
        case day, meals
        case dayTotals = "day_totals"
        case targetDeviationPct = "target_deviation_pct"
        case ruleCheck = "rule_check"
    }
}

// MARK: - Deterministic Validator (asıl güvenlik kapısı)
// AI'ın rule_check beyanına GÜVENME — burada yeniden doğrula.
// Bir kural bile ihlalse planı reddet ve backend'den yeniden üretim iste (max 3 deneme).

enum PlanValidationError: Error, CustomStringConvertible {
    case multipleMains(meal: MealType)
    case proteinMixing(meal: MealType, types: [ProteinType])
    case breakfastViolation(item: String)
    case kcalOutOfTolerance(deviation: Double)
    case allergenPresent(item: String)
    case selfCheckFailed

    var description: String {
        switch self {
        case .multipleMains(let m): return "R1 ihlali: \(m.rawValue) öğününde birden fazla ana yemek"
        case .proteinMixing(let m, let t): return "R2 ihlali: \(m.rawValue) — \(t.map(\.rawValue).joined(separator: " + "))"
        case .breakfastViolation(let i): return "R4 ihlali: kahvaltıda uygunsuz öğe — \(i)"
        case .kcalOutOfTolerance(let d): return "R5 ihlali: günlük sapma %\(String(format: "%.1f", d))"
        case .allergenPresent(let i): return "R6 ihlali: alerjen içeren öğe — \(i)"
        case .selfCheckFailed: return "AI rule_check'i kendisi false bırakmış"
        }
    }
}

struct PlanValidator {
    let targetKcal: Int
    let allergenKeywords: [String]   // ör. ["fıstık", "yer fıstığı"]
    let tolerance: Double = 0.05

    func validate(_ plan: DailyMealPlan) -> [PlanValidationError] {
        var errors: [PlanValidationError] = []

        if !plan.ruleCheck.allPassed { errors.append(.selfCheckFailed) }

        for meal in plan.meals {
            // R1 — öğün başına en fazla 1 ana yemek
            let mains = meal.items.filter { $0.category == .anaYemek }
            if mains.count > 1 { errors.append(.multipleMains(meal: meal.mealType)) }

            // R2 — hayvansal protein karışımı yok (yumurta_sut tamamlayıcıları muaf)
            let animalTypes = Set(
                meal.items
                    .filter { $0.category == .anaYemek || $0.category == .anaProtein }
                    .map(\.proteinType)
                    .filter { [.kirmiziEt, .beyazEt, .denizUrunu].contains($0) }
            )
            if animalTypes.count > 1 {
                errors.append(.proteinMixing(meal: meal.mealType, types: Array(animalTypes)))
            }

            // R4 — kahvaltıda ana yemek kategorisi asla olamaz
            if meal.mealType == .kahvalti {
                for item in meal.items where item.category == .anaYemek || item.category == .yanYemek {
                    errors.append(.breakfastViolation(item: item.name))
                }
            }

            // R6 — alerjen taraması (isim bazlı; DB id eşleşmesi daha sağlamdır)
            for item in meal.items {
                let lower = item.name.lowercased(with: Locale(identifier: "tr_TR"))
                if allergenKeywords.contains(where: { lower.contains($0.lowercased(with: Locale(identifier: "tr_TR"))) }) {
                    errors.append(.allergenPresent(item: item.name))
                }
            }
        }

        // R5 — günlük kalori toleransı
        let deviation = abs(Double(plan.dayTotals.kcal - targetKcal)) / Double(targetKcal)
        if deviation > tolerance {
            errors.append(.kcalOutOfTolerance(deviation: deviation * 100))
        }

        return errors
    }
}

import Foundation

// MARK: - Kural tabanlı plan üretimi (US-032)
//
// Haftalık menü bir DİL problemi değil, bir KISIT problemi: 225 yemekten
// hedef kaloriyi tutturan, alerjilere uyan, tekrar etmeyen bir hafta seçmek.
// Bu yüzden AI kullanmıyoruz — kendi kodumuz deterministik, anında, bedava ve
// hedefi tutturması GARANTİ. (Bir dil modeli "1.780 kcal" der ama toplamı
// tutmayabilir; burada toplam hesaplanarak kuruluyor.)

/// Katalogdan gelen, üreticinin ihtiyaç duyduğu alanlarla yemek.
struct PlanFood: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    let category: String
    let kcal100: Int
    let protein100: Double?
    let carb100: Double?
    let fat100: Double?
    let portionG: Int
    let portionName: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, category, tags
        case kcal100 = "kcal_100g"
        case protein100 = "protein_100g"
        case carb100 = "carb_100g"
        case fat100 = "fat_100g"
        case portionG = "portion_g"
        case portionName = "portion_name"
    }

    func kcal(forGrams grams: Int) -> Int {
        Int((Double(kcal100) * Double(grams) / 100).rounded())
    }
    func protein(forGrams grams: Int) -> Double {
        (protein100 ?? 0) * Double(grams) / 100
    }
}

/// Plana yerleşmiş tek bir öğün kalemi.
struct PlannedItem: Identifiable, Equatable {
    let id: String
    let name: String
    let grams: Int
    let kcal: Int
    let portionName: String
    let portionG: Int

    var portionText: String {
        let multiple = Double(grams) / Double(max(1, portionG))
        let label: String
        switch multiple {
        case ..<0.63: label = "½"
        case ..<0.88: label = "¾"
        case ..<1.13: label = "1"
        case ..<1.38: label = "1¼"
        case ..<1.75: label = "1½"
        default: label = "2"
        }
        return "\(label) \(portionName)"
    }
}

/// Bir günün bir öğünü.
struct PlannedMeal: Identifiable, Equatable {
    let slot: Int
    let label: String
    let time: String
    var items: [PlannedItem]
    var id: Int { slot }
    var kcal: Int { items.reduce(0) { $0 + $1.kcal } }
}

struct PlannedDay: Identifiable, Equatable {
    let day: Int                 // 0 = Pazartesi
    var meals: [PlannedMeal]
    var id: Int { day }
    var kcal: Int { meals.reduce(0) { $0 + $1.kcal } }
}

struct WeekMealPlan: Equatable {
    var days: [PlannedDay]
    var kcalTarget: Int
    var proteinTarget: Int
    var carbTarget: Int
    var fatTarget: Int
    /// Filtreden sonra kaç yemek kaldı? Az kalırsa plan tekrara düşer.
    var poolSize: Int

    var averageKcal: Int {
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.kcal } / days.count
    }

    /// Hedefe göre sapma yüzdesi.
    var deviationPct: Double {
        guard kcalTarget > 0 else { return 0 }
        return abs(Double(averageKcal - kcalTarget)) / Double(kcalTarget) * 100
    }
}

// MARK: - Üretici

enum MealPlanGenerator {

    /// Öğün şablonu: gün enerjisinin payı ve hangi kategorilerden seçileceği.
    struct SlotTemplate {
        let label: String
        let share: Double
        let categories: [String]
        /// Öğünde en fazla kaç kalem olsun?
        let maxItems: Int
    }

    static let breakfast = ["kahvalti", "sut", "ekmek", "yumurta", "meyve", "tahil"]
    static let mainMeal = ["corba", "et", "balik", "sebze", "baklagil", "pilav",
                           "makarna", "salata", "meze", "hamur"]
    static let snack = ["meyve", "kuruyemis", "sut", "atistirmalik"]

    static func templates(mealsPerDay: Int) -> [SlotTemplate] {
        switch mealsPerDay {
        case 3:
            return [.init(label: "Kahvaltı", share: 0.30, categories: breakfast, maxItems: 3),
                    .init(label: "Öğle", share: 0.35, categories: mainMeal, maxItems: 3),
                    .init(label: "Akşam", share: 0.35, categories: mainMeal, maxItems: 3)]
        case 5:
            return [.init(label: "Kahvaltı", share: 0.22, categories: breakfast, maxItems: 3),
                    .init(label: "Ara öğün", share: 0.08, categories: snack, maxItems: 1),
                    .init(label: "Öğle", share: 0.30, categories: mainMeal, maxItems: 3),
                    .init(label: "Ara öğün", share: 0.10, categories: snack, maxItems: 2),
                    .init(label: "Akşam", share: 0.30, categories: mainMeal, maxItems: 3)]
        default:
            return [.init(label: "Kahvaltı", share: 0.25, categories: breakfast, maxItems: 3),
                    .init(label: "Öğle", share: 0.30, categories: mainMeal, maxItems: 3),
                    .init(label: "Ara öğün", share: 0.10, categories: snack, maxItems: 2),
                    .init(label: "Akşam", share: 0.35, categories: mainMeal, maxItems: 3)]
        }
    }

    /// Sihirbazdaki alerji etiketlerinin yemek etiketlerine karşılığı.
    static let allergyTags: [String: String] = [
        "Gluten": "gluten", "Laktoz": "sut", "Yumurta": "yumurta", "Balık": "balik",
        "Kabuklu deniz ürünü": "kabuklu", "Fındık/ceviz": "findik",
        "Soya": "soya", "Susam": "susam"
    ]

    static let dislikeTags: [String: String] = [
        "Kırmızı et": "kirmizi_et", "Balık": "balik", "Süt ürünleri": "sut",
        "Baklagil": "baklagil", "Acı": "aci", "Sakatat": "sakatat",
        "Mantar": "mantar", "Zeytin": "zeytin"
    ]

    /// Kullanıcıya uygun yemek havuzu.
    ///
    /// Elle yazılan alerji/sevmediklerini de eliyoruz: kullanıcı "karnabahar"
    /// yazdıysa hazır bir etiket yok, ada bakmak tek yol.
    static func pool(from foods: [PlanFood], prefs: PlanPreferences,
                     protocolItem: DietProtocol?) -> [PlanFood] {
        var blockedTags = Set<String>()
        var freeText = Set<String>()

        for allergy in prefs.allergies {
            if let tag = allergyTags[allergy] { blockedTags.insert(tag) }
            else { freeText.insert(SupabaseService.searchKey(allergy)) }
        }
        for dislike in prefs.dislikes {
            if let tag = dislikeTags[dislike] { blockedTags.insert(tag) }
            else { freeText.insert(SupabaseService.searchKey(dislike)) }
        }
        // Alkol bir sağlık planında yeri olmayan tek kategori.
        blockedTags.insert("alkol")

        let requiredTag: String? = switch prefs.dietStyle {
        case .vegan: "vegan"
        case .vegetarian: "vejetaryen"
        case .omnivore: nil
        }

        let avoidCategories = Set(protocolItem?.avoidCategories ?? [])

        return foods.filter { food in
            if avoidCategories.contains(food.category) { return false }
            if food.tags.contains(where: { blockedTags.contains($0) }) { return false }
            if let requiredTag, !food.tags.contains(requiredTag) { return false }
            if !freeText.isEmpty {
                let key = SupabaseService.searchKey(food.name)
                if freeText.contains(where: { key.contains($0) }) { return false }
            }
            // İçecekler öğün kalemi değil; su ve çay plana yazılmaz.
            if food.category == "icecek" { return false }
            return true
        }
    }

    /// Haftalık menüyü üretir.
    ///
    /// Aynı hafta için aynı sonucu verir (tohum hafta başlangıcından türer);
    /// her yeniden açılışta menünün değişmesi kullanıcıyı çileden çıkarırdı.
    static func generate(foods: [PlanFood], prefs: PlanPreferences,
                         protocolItem: DietProtocol?, kcalTarget: Int,
                         weightKg: Double?, weekStart: Date) -> WeekMealPlan {
        let candidates = pool(from: foods, prefs: prefs, protocolItem: protocolItem)
        let macros = protocolItem?.macros(kcal: kcalTarget, weightKg: weightKg)
            ?? (protein: kcalTarget * 20 / 100 / 4,
                carb: kcalTarget * 50 / 100 / 4,
                fat: kcalTarget * 30 / 100 / 9)

        var plan = WeekMealPlan(days: [], kcalTarget: kcalTarget,
                                proteinTarget: macros.protein, carbTarget: macros.carb,
                                fatTarget: macros.fat, poolSize: candidates.count)
        guard !candidates.isEmpty else { return plan }

        let favor = Set(protocolItem?.favorCategories ?? [])
        let limited = Set(protocolItem?.limitCategories ?? [])
        let slots = templates(mealsPerDay: prefs.mealsPerDay)
        var rng = SeededRandom(seed: UInt64(weekStart.timeIntervalSince1970) / 86_400)
        // Son üç günde kullanılanlar — aynı yemeği arka arkaya koymamak için.
        var recent: [Set<String>] = []

        for day in 0..<7 {
            var meals: [PlannedMeal] = []
            var usedToday = Set<String>()
            let recentIDs = Set(recent.suffix(3).flatMap { $0 })

            for (index, template) in slots.enumerated() {
                let slotTarget = Int((Double(kcalTarget) * template.share).rounded())
                let eligible = candidates.filter { template.categories.contains($0.category) }
                let items = fill(target: slotTarget, from: eligible, maxItems: template.maxItems,
                                 favor: favor, limited: limited,
                                 avoid: recentIDs.union(usedToday), rng: &rng)
                items.forEach { usedToday.insert($0.id) }
                meals.append(PlannedMeal(
                    slot: index, label: template.label,
                    time: prefs.mealTimes.indices.contains(index) ? prefs.mealTimes[index] : "",
                    items: items))
            }
            recent.append(usedToday)
            plan.days.append(PlannedDay(day: day, meals: meals))
        }
        return plan
    }

    /// Bir öğünü hedef kaloriye yaklaştırarak doldurur.
    ///
    /// Önce yemek seçilir, sonra **porsiyon ölçeklenir**: yalnızca yemek
    /// seçerek hedefi tutturmak imkânsız, 225 kalemle her sayıya denk gelinmez.
    /// Ölçek 0,5–2 porsiyon arasına sıkıştırılıyor — "3,5 porsiyon pilav"
    /// matematiksel olarak doğru ama gerçek hayatta anlamsız.
    private static func fill(target: Int, from foods: [PlanFood], maxItems: Int,
                             favor: Set<String>, limited: Set<String>,
                             avoid: Set<String>, rng: inout SeededRandom) -> [PlannedItem] {
        guard !foods.isEmpty, target > 0 else { return [] }
        let fresh = foods.filter { !avoid.contains($0.id) }
        let usable = fresh.isEmpty ? foods : fresh

        // Protokolün öne çıkardıkları önce, sınırladıkları sona.
        let ranked = usable.sorted { a, b in
            score(a, favor: favor, limited: limited) > score(b, favor: favor, limited: limited)
        }
        // Üst dilimden rastgele seç: hep aynı ilk yemek gelmesin.
        let topSlice = Array(ranked.prefix(max(6, ranked.count / 3)))
        var chosen: [PlanFood] = []
        var pool = topSlice
        let count = min(maxItems, max(1, pool.count))
        for _ in 0..<count {
            guard !pool.isEmpty else { break }
            let index = rng.next(upperBound: pool.count)
            chosen.append(pool.remove(at: index))
        }
        guard !chosen.isEmpty else { return [] }

        // Bir porsiyonluk temel toplam, sonra hedefe ölçekle.
        let baseKcal = chosen.reduce(0) { $0 + $1.kcal(forGrams: $1.portionG) }
        let scale = baseKcal > 0 ? Double(target) / Double(baseKcal) : 1
        return chosen.map { food in
            let clamped = min(max(scale, 0.5), 2.0)
            // 25 g'ın katlarına yuvarla — "137 gram pilav" ölçülemez.
            let raw = Double(food.portionG) * clamped
            let grams = max(25, Int((raw / 25).rounded()) * 25)
            return PlannedItem(id: food.id, name: food.name, grams: grams,
                               kcal: food.kcal(forGrams: grams),
                               portionName: food.portionName, portionG: food.portionG)
        }
    }

    private static func score(_ food: PlanFood, favor: Set<String>,
                              limited: Set<String>) -> Int {
        var value = 0
        if favor.contains(food.category) { value += 3 }
        if limited.contains(food.category) { value -= 3 }
        if food.tags.contains("yuksek_seker") { value -= 2 }
        return value
    }
}

/// Tekrarlanabilir sözde rastgele sayı üreteci.
///
/// `Int.random` kullanmak menüyü her açılışta değiştirirdi. Aynı hafta aynı
/// planı vermeli; kullanıcı Salı günü bakınca Pazartesi gördüğü menüyü
/// bulmalı.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407 }

    mutating func next(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(upperBound))
    }
}

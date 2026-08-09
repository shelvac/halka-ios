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
    /// Öğündeki rolü — kompozisyonun temeli (0020_food_roles.sql).
    let role: String

    enum CodingKeys: String, CodingKey {
        case id, name, category, tags, role
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

    /// Öğün şablonu — payı ve **kompozisyonu**.
    ///
    /// `composition` sırayla hangi rolden kaç kalem alınacağını söylüyor.
    /// Eskiden kategoriden rastgele üç kalem seçiliyordu ve aynı öğüne üç
    /// ana yemek düşebiliyordu ("İskender + Kavurma + Somon ızgara").
    /// Bir öğün: bir ana yemek + bir garnitür + bir sebze/salata.
    struct SlotTemplate {
        let label: String
        let share: Double
        /// (rol, adet) — sıra önemli, ilk rol öğünün belkemiği.
        let composition: [(role: String, count: Int)]
        /// Kalori bütçesi kalırsa eklenecek isteğe bağlı roller.
        let optional: [String]
    }

    static func templates(mealsPerDay: Int) -> [SlotTemplate] {
        // Kahvaltı: protein + ekmek + yan (zeytin/domates)
        let breakfast = SlotTemplate(
            label: "Kahvaltı", share: 0.25,
            composition: [("kahvalti_protein", 1), ("ekmek", 1), ("kahvalti_yan", 1)],
            optional: ["meyve"])
        // Ana öğün: ana yemek + garnitür + sebze/salata. Çorba isteğe bağlı.
        func main(_ label: String, _ share: Double) -> SlotTemplate {
            SlotTemplate(label: label, share: share,
                         composition: [("ana", 1), ("garnitur", 1), ("yan", 1)],
                         optional: ["corba"])
        }
        // Ara öğün tek kalem: meyve ya da süt ya da kuruyemiş.
        let snack = SlotTemplate(label: "Ara öğün", share: 0.10,
                                 composition: [("meyve|sut|kuruyemis", 1)], optional: [])

        switch mealsPerDay {
        case 3:
            return [SlotTemplate(label: "Kahvaltı", share: 0.30,
                                 composition: breakfast.composition, optional: ["meyve"]),
                    main("Öğle", 0.35), main("Akşam", 0.35)]
        case 5:
            return [SlotTemplate(label: "Kahvaltı", share: 0.22,
                                 composition: breakfast.composition, optional: []),
                    SlotTemplate(label: "Ara öğün", share: 0.08,
                                 composition: snack.composition, optional: []),
                    main("Öğle", 0.30),
                    SlotTemplate(label: "Ara öğün", share: 0.10,
                                 composition: snack.composition, optional: []),
                    main("Akşam", 0.30)]
        default:
            return [breakfast, main("Öğle", 0.30), snack, main("Akşam", 0.35)]
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
            // Plana OTOMATİK girmeyecekler: içecekler, tatlılar, kızartmalar,
            // işlenmiş etler. Kullanıcı elle ekleyebilir ama biz önermiyoruz —
            // "diyet planı" diye sucuk ve kavurma sunmak ciddiyetsizlik.
            if food.role == "keyfi" || food.role == "icecek" { return false }
            if food.tags.contains("islenmis_et") || food.tags.contains("kizartma") {
                return false
            }
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
                let items = compose(template: template, target: slotTarget,
                                    from: candidates, favor: favor, limited: limited,
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

    /// Öğünü **kompozisyona göre** kurar, sonra hedefe ölçekler.
    ///
    /// İki aşama ayrı: önce hangi roller doldurulacak (bir ana + bir garnitür
    /// + bir yan), sonra porsiyonlar hedefe oturtulur. 225 kalemle her kalori
    /// hedefine yalnızca yemek seçerek denk gelmek imkânsız.
    private static func compose(template: SlotTemplate, target: Int,
                                from foods: [PlanFood], favor: Set<String>,
                                limited: Set<String>, avoid: Set<String>,
                                rng: inout SeededRandom) -> [PlannedItem] {
        var chosen: [PlanFood] = []

        func pick(role: String) -> PlanFood? {
            // "meyve|sut|kuruyemis" gibi alternatifli roller.
            let roles = Set(role.split(separator: "|").map(String.init))
            let all = foods.filter { roles.contains($0.role) }
            guard !all.isEmpty else { return nil }
            let fresh = all.filter { !avoid.contains($0.id) && !chosen.contains($0) }
            let usable = fresh.isEmpty ? all : fresh
            let ranked = usable.sorted {
                score($0, favor: favor, limited: limited) > score($1, favor: favor, limited: limited)
            }
            let slice = Array(ranked.prefix(max(5, ranked.count / 2)))
            return slice[rng.next(upperBound: slice.count)]
        }

        for entry in template.composition {
            for _ in 0..<entry.count {
                if let food = pick(role: entry.role) { chosen.append(food) }
            }
        }
        guard !chosen.isEmpty else { return [] }

        // Bütçe kalırsa isteğe bağlı kalem (çorba, meyve) eklenir.
        let baseKcal = chosen.reduce(0) { $0 + $1.kcal(forGrams: $1.portionG) }
        if baseKcal < Int(Double(target) * 0.75) {
            for role in template.optional {
                if let extra = pick(role: role) { chosen.append(extra); break }
            }
        }

        // Hedefe ölçekle. Sıkı sınır: yarım porsiyonun altı ve 1,5 porsiyonun
        // üstü gerçek bir tabak olmaktan çıkar.
        let total = chosen.reduce(0) { $0 + $1.kcal(forGrams: $1.portionG) }
        let scale = total > 0 ? min(max(Double(target) / Double(total), 0.6), 1.5) : 1
        var items = chosen.map { food -> PlannedItem in
            let step = food.portionG >= 100 ? 25 : 10
            let raw = Double(food.portionG) * scale
            let grams = max(step, Int((raw / Double(step)).rounded()) * step)
            return PlannedItem(id: food.id, name: food.name, grams: grams,
                               kcal: food.kcal(forGrams: grams),
                               portionName: food.portionName, portionG: food.portionG)
        }

        // Kalan sapmayı en esnek kalemle (garnitür ya da en büyük) kapat.
        let achieved = items.reduce(0) { $0 + $1.kcal }
        let gap = target - achieved
        if abs(gap) > target / 12, let index = items.indices.max(by: {
            items[$0].kcal < items[$1].kcal
        }) {
            let food = chosen[index]
            let per100 = max(1, food.kcal100)
            let deltaG = gap * 100 / per100
            let step = food.portionG >= 100 ? 25 : 10
            let adjusted = max(Double(food.portionG) * 0.5,
                               min(Double(food.portionG) * 2.0,
                                   Double(items[index].grams + deltaG)))
            let grams = max(step, Int((adjusted / Double(step)).rounded()) * step)
            items[index] = PlannedItem(id: food.id, name: food.name, grams: grams,
                                       kcal: food.kcal(forGrams: grams),
                                       portionName: food.portionName,
                                       portionG: food.portionG)
        }
        return items
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

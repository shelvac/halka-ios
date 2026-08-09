import Foundation

/// AI'a giden gün özeti — @MainActor dışında: Encodable'ın sentezlenen
/// encode(to:) metodu izole olamaz.
private struct DaySummaryPayload: Encodable {
    let gun: String
    let ana_yemekler: [String]
    let kirmizi_et: Int
    let balik: Int
}

private struct PlanDayPayload: Encodable {
    let hedef: String
    let kalori: Int
    let makrolar: [String: Int]
    let protokol: String
    let alerjiler: [String]
    let sevilmeyenler: [String]
    let ogun_sayisi: Int
    let ogun_saatleri: [String]
    let gun: String
    let onceki_gunler_ozeti: [DaySummaryPayload]
    let duzeltilecek_hatalar: [String]?
}

// MARK: - Haftalık plan orkestrasyonu (US-032 · US-034)
//
// İki katman:
//   1. AI (Halka Coach istemi): kültürel olarak tutarlı öğün KOMPOZE eder —
//      "önce kompozisyon, sonra sayılar". Sucuklu kahvaltı ve üç ana yemekli
//      öğle sorununu kökten çözen katman bu.
//   2. Deterministik doğrulayıcı (PlanValidator): AI'ın beyanına güvenilmez.
//      R1 (tek ana yemek), R2 (protein karışımı yok), R4 (kahvaltı bütünlüğü),
//      R5 (±%5 kalori), R6 (alerjen yok) burada YENİDEN denetlenir.
//
// Doğrulama düşerse hatalar modele geri verilip bir kez daha denenir; yine
// düşerse o gün KURAL TABANLI üreticiden gelir. AI'a hiç ulaşılamazsa tüm
// hafta kural tabanlı kurulur — plan özelliği sağlayıcıya rehin değil.

extension AppModel {

    static let dayNames = ["pazartesi", "sali", "carsamba", "persembe",
                           "cuma", "cumartesi", "pazar"]

    /// Sağlık bayraklarının yiyecek kısıtı karşılığı.
    ///
    /// KVKK: sihirbazda "bu bilgi hiçbir yere gönderilmez" sözü verildi.
    /// Bayrakların KENDİSİ cihazdan çıkmıyor; modele yalnızca türetilmiş
    /// kaçınılacaklar listesi gidiyor ("tansiyon" değil, "sucuk, turşu").
    static let healthDrivenExclusions: [String: [String]] = [
        "tansiyon": ["sucuk", "salam", "pastırma", "turşu", "salamura zeytin"],
        "gut": ["sakatat", "ciğer", "kokoreç", "kavurma", "midye", "karides"],
        "diyabet_ilac": ["baklava", "tatlı", "reçel", "bal", "şekerli içecek"],
        "kalp": ["kavurma", "kaymak", "tereyağı", "kızartma"],
        "bobrek": []        // protein sınırı protokol kapısında uygulanıyor
    ]

    static func aiExclusions(healthFlags: Set<String>) -> [String] {
        healthFlags.flatMap { healthDrivenExclusions[$0] ?? [] }.sorted()
    }

    /// Alerji seçimlerinin isim-bazlı doğrulama anahtarları (PlanValidator).
    static let allergenKeywords: [String: [String]] = [
        "Gluten": ["ekmek", "bulgur", "makarna", "börek", "buğday", "şehriye",
                   "kuskus", "erişte", "simit"],
        "Laktoz": ["süt", "yoğurt", "peynir", "ayran", "kefir", "cacık", "kaymak"],
        "Yumurta": ["yumurta", "omlet", "menemen"],
        "Balık": ["balık", "somon", "levrek", "çupra", "hamsi", "palamut", "ton"],
        "Kabuklu deniz ürünü": ["karides", "midye", "kalamar"],
        "Fındık/ceviz": ["fındık", "ceviz", "badem", "fıstık", "kaju"],
        "Soya": ["soya"],
        "Susam": ["susam", "tahin"]
    ]

    /// AI protokol adı eşlemesi. Vegan/vejetaryen tarz, protokolden daha
    /// katı bir kısıt olduğu için onu ezer.
    static func aiProtocolName(_ prefs: PlanPreferences) -> String {
        switch prefs.dietStyle {
        case .vegan: return "Vegan"
        case .vegetarian: return "Vejetaryen"
        case .omnivore: break
        }
        switch prefs.protocolKey {
        case "akdeniz": return "Akdeniz"
        case "yuksek_protein": return "Yuksek_Protein"
        case "dash": return "DASH"
        case "dusuk_karb": return "Dusuk_Karb"
        case "ketojenik": return "Ketojenik"
        case "dukan": return "Dukan"
        // Lipödem düşük karb ilkeleriyle, aralıklı oruç dengeli düzenle
        // üretilir; ikisi de istemin protokol kümesinde yok.
        case "lipodem": return "Dusuk_Karb"
        default: return "Dengeli_TUBER"
        }
    }

    /// Sihirbaz tamamlanınca haftanın menüsünü ve antrenmanını kurar.
    func buildWeeklyPlan(_ prefs: PlanPreferences) async {
        planBusy = true
        planProgress = 0
        defer { planBusy = false }

        let foods = await SupabaseService.shared.fetchPlanFoods()
        let exercises = await SupabaseService.shared.fetchPlanExercises()
        let protocols = await SupabaseService.shared.fetchProtocols()
        let chosen = protocols.first { $0.key == prefs.protocolKey }
        let kcalTarget = profile.calorieGoal ?? Int(RingKind.nutrition.goal)
        let macros = chosen?.macros(kcal: kcalTarget, weightKg: profile.weightKg)
            ?? (protein: kcalTarget * 20 / 100 / 4,
                carb: kcalTarget * 50 / 100 / 4,
                fat: kcalTarget * 30 / 100 / 9)

        // Antrenman her zaman kural tabanlı — DSÖ/ACSM hacmi deterministik iş.
        workoutPlan = WorkoutPlanGenerator.generate(
            exercises: exercises, prefs: prefs,
            activity: profile.activityLevel, weekStart: weekStart)

        // Kural tabanlı hafta: AI düşerse günün yedeği buradan.
        let fallback = MealPlanGenerator.generate(
            foods: foods, prefs: prefs, protocolItem: chosen,
            kcalTarget: kcalTarget, weightKg: profile.weightKg, weekStart: weekStart)

        var keywords = prefs.allergies.flatMap {
            Self.allergenKeywords[$0] ?? [$0.lowercased(with: Locale(identifier: "tr_TR"))]
        }
        keywords += prefs.dislikes.compactMap {
            MealPlanGenerator.dislikeTags[$0] == nil
                ? $0.lowercased(with: Locale(identifier: "tr_TR")) : nil
        }
        let validator = PlanValidator(targetKcal: kcalTarget, allergenKeywords: keywords)

        let exclusions = (prefs.dislikes.sorted()
                          + Self.aiExclusions(healthFlags: prefs.healthFlags))
        var days: [PlannedDay] = []
        var summaries: [DaySummaryPayload] = []
        var aiDayCount = 0
        var aiReachable = true

        for dayIndex in 0..<7 {
            var planned: PlannedDay? = nil
            var lastErrors: [String] = []

            if aiReachable {
                for _ in 0..<2 {
                    let payload = PlanDayPayload(
                        hedef: prefs.goal == .lose ? "kilo_ver"
                             : prefs.goal == .gain ? "kas_kazan" : "koru",
                        kalori: kcalTarget,
                        makrolar: ["protein": macros.protein, "karb": macros.carb,
                                   "yag": macros.fat],
                        protokol: Self.aiProtocolName(prefs),
                        alerjiler: prefs.allergies.sorted(),
                        sevilmeyenler: exclusions,
                        ogun_sayisi: prefs.mealsPerDay,
                        ogun_saatleri: prefs.mealTimes,
                        gun: Self.dayNames[dayIndex],
                        onceki_gunler_ozeti: summaries,
                        duzeltilecek_hatalar: lastErrors.isEmpty ? nil : lastErrors)
                    do {
                        let json = String(data: try JSONEncoder().encode(payload),
                                          encoding: .utf8) ?? "{}"
                        let aiDay = try await SupabaseService.shared
                            .generateMealPlanDay(inputJSON: json)
                        let errors = validator.validate(aiDay)
                        if errors.isEmpty {
                            planned = Self.plannedDay(from: aiDay, dayIndex: dayIndex,
                                                      times: prefs.mealTimes)
                            summaries.append(Self.summary(of: aiDay))
                            aiDayCount += 1
                            break
                        }
                        // Hataları modele geri ver — kör tekrar yerine düzeltme.
                        lastErrors = errors.map(\.description)
                    } catch {
                        // Kota/ağ hatasında kalan günler için AI'ı hiç deneme;
                        // 7 kez zaman aşımı beklemek planı dakikalara sürer.
                        AuthLog.warn("planAI", error)
                        aiReachable = false
                        break
                    }
                }
            }

            if planned == nil, fallback.days.indices.contains(dayIndex) {
                planned = fallback.days[dayIndex]
            }
            if let planned { days.append(planned) }
            planProgress = dayIndex + 1
        }

        mealPlan = WeekMealPlan(days: days, kcalTarget: kcalTarget,
                                proteinTarget: macros.protein,
                                carbTarget: macros.carb, fatTarget: macros.fat,
                                poolSize: fallback.poolSize)
        planSource = aiDayCount == 7 ? "ai" : aiDayCount > 0 ? "mixed" : "rules"
        planPreferences = prefs
    }

    // MARK: AI günü → uygulama modeli

    static func plannedDay(from ai: DailyMealPlan, dayIndex: Int,
                           times: [String]) -> PlannedDay {
        let meals = ai.meals.enumerated().map { index, meal in
            PlannedMeal(
                slot: index,
                label: Self.mealLabel(meal.mealType),
                // Kullanıcının sihirbazda seçtiği saatler esas; model kendi
                // saat önerdiyse ezilir.
                time: times.indices.contains(index) ? times[index] : meal.time,
                items: meal.items.map { item in
                    PlannedItem(id: "\(item.name)-\(index)",
                                name: item.name,
                                grams: item.grams,
                                kcal: item.kcal,
                                portionName: Self.unitLabel(item.unit),
                                portionG: max(1, item.grams),
                                portionLabel: Self.portionLabel(item))
                })
        }
        return PlannedDay(day: dayIndex, meals: meals)
    }

    static func mealLabel(_ type: MealType) -> String {
        switch type {
        case .kahvalti: return "Kahvaltı"
        case .ogle: return "Öğle"
        case .araOgun: return "Ara öğün"
        case .aksam: return "Akşam"
        }
    }

    static func unitLabel(_ unit: PortionUnit) -> String {
        switch unit {
        case .adet: return "adet"
        case .dilim: return "dilim"
        case .kase: return "kase"
        case .porsiyon: return "porsiyon"
        case .avuc: return "avuç"
        case .bardak: return "bardak"
        case .yemekKasigi: return "yemek kaşığı"
        case .gram: return "porsiyon"
        }
    }

    /// "2 adet", "4 yemek kaşığı", "½ kase".
    static func portionLabel(_ item: FoodItem) -> String {
        let amount: String
        if item.amount == item.amount.rounded() {
            amount = "\(Int(item.amount))"
        } else if abs(item.amount - 0.5) < 0.01 {
            amount = "½"
        } else {
            amount = String(format: "%.1f", item.amount)
                .replacingOccurrences(of: ".", with: ",")
        }
        return "\(amount) \(unitLabel(item.unit))"
    }

    private nonisolated static func summary(of plan: DailyMealPlan) -> DaySummaryPayload {
        let mains = plan.meals.flatMap { $0.items }
            .filter { $0.category == .anaYemek }
        return DaySummaryPayload(
            gun: plan.day.rawValue,
            ana_yemekler: mains.map(\.name),
            kirmizi_et: mains.filter { $0.proteinType == .kirmiziEt }.count,
            balik: mains.filter { $0.proteinType == .denizUrunu }.count)
    }
}

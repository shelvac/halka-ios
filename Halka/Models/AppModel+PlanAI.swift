import Foundation

/// AI'a giden yükler — @MainActor dışında: Encodable'ın sentezlenen
/// encode(to:) metodu izole olamaz ve paralel görevlerden erişiliyorlar.
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
    /// Paralel üretimin çeşitlilik güvencesi: istemcinin dayattığı protein
    /// rotasyonu (aşağıya bak).
    let rotasyon_talimati: String?
    let varyasyon_notu: String?
    let duzeltilecek_hatalar: [String]?
}

private let planDayNames = ["pazartesi", "sali", "carsamba", "persembe",
                            "cuma", "cumartesi", "pazar"]

/// Haftalık planın hangi yarısı kurulacak — "beğenmedim" akışı yalnızca
/// besin ya da yalnızca antrenmanı yeniler, diğerine dokunmaz.
enum PlanPart: Hashable { case meals, workouts }

private func makePlanPayloadJSON(
    day: Int, hedef: String, kalori: Int, makrolar: [String: Int],
    protokol: String, alerjiler: [String], sevilmeyenler: [String],
    ogunSayisi: Int, saatler: [String], previous: [DaySummaryPayload],
    rotasyon: String?, variation: Int, errors: [String]
) -> String {
    let payload = PlanDayPayload(
        hedef: hedef, kalori: kalori, makrolar: makrolar, protokol: protokol,
        alerjiler: alerjiler, sevilmeyenler: sevilmeyenler,
        ogun_sayisi: ogunSayisi, ogun_saatleri: saatler,
        gun: planDayNames[day], onceki_gunler_ozeti: previous,
        rotasyon_talimati: rotasyon,
        varyasyon_notu: variation > 0
            ? "Kullanıcı önceki planı beğenmedi (deneme #\(variation + 1)). Belirgin biçimde FARKLI yemekler seç."
            : nil,
        duzeltilecek_hatalar: errors.isEmpty ? nil : errors)
    guard let data = try? JSONEncoder().encode(payload),
          let json = String(data: data, encoding: .utf8) else { return "{}" }
    return json
}

/// Ağ çağrısını süreyle sınırlar. Askıda kalan tek bir istek "Plan
/// hazırlanıyor" ekranını sonsuza kadar tutuyordu.
private func withPlanTimeout<T: Sendable>(
    seconds: Double, _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw SupabaseService.MealAnalysisError.failed("Plan isteği zaman aşımına uğradı.")
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - Haftalık plan orkestrasyonu (US-032 · US-034)
//
// İki katman:
//   1. AI (Halka Coach istemi): kültürel olarak tutarlı öğün KOMPOZE eder.
//   2. PlanValidator: modelin beyanına güvenilmez — tek ana yemek, protein
//      karışımı, kahvaltı bütünlüğü, ±%5 kalori, alerjen ve yasaklı yiyecek
//      istemcide yeniden denetlenir.
//
// HIZ: günler ardışık üretildiğinde hafta 3-6 dakika sürüyordu ve kullanıcı
// donmuş bir ekrana bakıyordu. Artık iki paralel dalga (4 + 3 gün) ile
// ~1 dakika. Ardışıklığın tek gerekçesi çeşitlilikti (önceki günlerin
// özeti); onun yerini istemcinin dayattığı PROTEİN ROTASYONU aldı —
// çeşitlilik artık modele değil, bize bağlı. İkinci dalga yine de ilk
// dalganın özetini alıyor (ad tekrarını azaltır).

extension AppModel {

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

    /// Hiçbir diyet planında yeri olmayanlar — Simge'nin sözüyle: "diyetlerde
    /// asla sucuk salam olmaz". Her zaman yasak.
    static let processedMeatBans = ["sucuk", "salam", "sosis", "pastırma"]
    /// Kilo verme hedefinde ek yasaklar.
    static let weightLossBans = ["iskender", "döner", "kavurma", "kokoreç", "kızartma"]

    static func bannedFoods(goal: PlanPreferences.Goal) -> [String] {
        goal == .lose ? processedMeatBans + weightLossBans : processedMeatBans
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

    /// Günün öğle/akşam ana yemeği için protein tipi rotasyonu.
    ///
    /// Paralel üretimde günler birbirini göremiyor; haftalık çeşitliliği
    /// (balık ≥2, kırmızı et ≤2, baklagil ≥2 — istemin R10'u) modele
    /// bırakmak yerine istemci dayatıyor. Deterministik: aynı hafta aynı
    /// rotasyon.
    static func rotationDirective(dayIndex: Int, prefs: PlanPreferences,
                                  variation: Int = 0) -> String? {
        guard prefs.dietStyle == .omnivore, (0..<7).contains(dayIndex) else { return nil }
        let protokol = aiProtocolName(prefs)
        var pairs: [(String, String)] = [
            ("beyaz_et", "deniz_urunu"),
            ("kirmizi_et", "bitkisel"),
            ("bitkisel", "beyaz_et"),
            ("deniz_urunu", "bitkisel"),
            ("beyaz_et", "kirmizi_et"),
            ("bitkisel", "beyaz_et"),
            ("deniz_urunu", "beyaz_et")
        ]
        if protokol == "Akdeniz" {
            // R7: Akdeniz'de kırmızı et haftada en fazla 1.
            pairs[4] = ("beyaz_et", "bitkisel")
        }
        if protokol == "Ketojenik" || protokol == "Dukan" {
            // R7: baklagil ana yemekleri bu protokollerde yok.
            pairs = [
                ("beyaz_et", "deniz_urunu"),
                ("kirmizi_et", "beyaz_et"),
                ("deniz_urunu", "beyaz_et"),
                ("beyaz_et", "deniz_urunu"),
                ("beyaz_et", "kirmizi_et"),
                ("deniz_urunu", "beyaz_et"),
                ("beyaz_et", "deniz_urunu")
            ]
        }
        // Varyasyon rotasyonu kaydırır: "başka plan" gerçekten başka olsun.
        let (lunch, dinner) = pairs[(dayIndex + variation) % pairs.count]
        return "Bugün öğle ana yemeğinin protein tipi \(lunch), akşamınki \(dinner) olmalı. "
             + "onceki_gunler_ozeti içindeki ana yemek adlarını tekrarlama."
    }

    /// Sonuç ekranı yalnızca istenen bölümleri gösterir; ama daha önce
    /// kurulmuş bir bölüm varsa (ör. tam plandan sonra sadece besin
    /// yenilendi) o görünür kalmalı.
    func recordPlanParts(_ parts: Set<PlanPart>) {
        planParts = parts
        if workoutPlan != nil { planParts.insert(.workouts) }
        if !(mealPlan?.days.isEmpty ?? true) { planParts.insert(.meals) }
    }

    /// Sihirbaz tamamlanınca haftanın menüsünü ve antrenmanını kurar.
    ///
    /// `mealPlan` günler geldikçe dolar — sonuç ekranı üretim bitmeden
    /// açılıp canlı ilerleme gösterebilsin.
    func buildWeeklyPlan(_ prefs: PlanPreferences,
                         parts: Set<PlanPart> = [.meals, .workouts],
                         variation: Int = 0) async {
        planBusy = true
        planProgress = 0
        recordPlanParts(parts)
        if parts.contains(.meals) { planSource = nil }
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
        // Varyasyon tohumu kaydırır: "başka program" farklı hareketler seçer.
        if parts.contains(.workouts) {
            workoutPlan = WorkoutPlanGenerator.generate(
                exercises: exercises, prefs: prefs,
                activity: profile.activityLevel,
                weekStart: weekStart.addingTimeInterval(TimeInterval(variation) * 604_800))
        }
        guard parts.contains(.meals) else {
            planPreferences = prefs
            return
        }

        // Kural tabanlı hafta: AI düşerse günün yedeği buradan.
        let fallbackWeek = weekStart.addingTimeInterval(TimeInterval(variation) * 604_800)
        var fallback = MealPlanGenerator.generate(
            foods: foods, prefs: prefs, protocolItem: chosen,
            kcalTarget: kcalTarget, weightKg: profile.weightKg, weekStart: fallbackWeek)
        if fallback.days.isEmpty {
            // Filtreler havuzu tamamen boşaltmış (ör. katı protokol + çok
            // kısıt). Yedek yedeksiz kalamaz: protokol kısıtları gevşetilir,
            // alerji/tarz filtreleri korunur. "Sadece Pzt-Sal-Çar üretmiş,
            // diğer günler yok" şikâyetinin kökü buydu — AI düşen günlerin
            // yedeği boş dizi olunca günler kayboluyordu.
            fallback = MealPlanGenerator.generate(
                foods: foods, prefs: prefs, protocolItem: nil,
                kcalTarget: kcalTarget, weightKg: profile.weightKg,
                weekStart: fallbackWeek)
        }

        var keywords = prefs.allergies.flatMap {
            Self.allergenKeywords[$0] ?? [$0.lowercased(with: Locale(identifier: "tr_TR"))]
        }
        keywords += prefs.dislikes.compactMap {
            MealPlanGenerator.dislikeTags[$0] == nil
                ? $0.lowercased(with: Locale(identifier: "tr_TR")) : nil
        }
        // Yasaklılar iki yerde birden: modele "önerme" diye gidiyor,
        // doğrulayıcıda "önerirsen reddederim" diye bekliyor.
        let banned = Self.bannedFoods(goal: prefs.goal)
        let validator = PlanValidator(targetKcal: kcalTarget,
                                      allergenKeywords: keywords,
                                      bannedKeywords: banned)
        let exclusions = Array(Set(prefs.dislikes
                          + Self.aiExclusions(healthFlags: prefs.healthFlags)
                          + banned)).sorted()

        // Görev kapanışlarına giren düz değerler.
        let hedef = prefs.goal == .lose ? "kilo_ver"
                  : prefs.goal == .gain ? "kas_kazan" : "koru"
        let makrolar = ["protein": macros.protein, "karb": macros.carb, "yag": macros.fat]
        let protokol = Self.aiProtocolName(prefs)
        let alerjiler = prefs.allergies.sorted()
        let saatler = prefs.mealTimes
        let ogunSayisi = prefs.mealsPerDay
        let rotations = (0..<7).map {
            Self.rotationDirective(dayIndex: $0, prefs: prefs, variation: variation)
        }

        // Canlı ekran: hedefler belli, günler geldikçe eklenecek.
        mealPlan = WeekMealPlan(days: [], kcalTarget: kcalTarget,
                                proteinTarget: macros.protein,
                                carbTarget: macros.carb, fatTarget: macros.fat,
                                poolSize: fallback.poolSize)

        var collected: [Int: PlannedDay] = [:]
        var summaryByDay: [Int: DaySummaryPayload] = [:]
        var aiDayCount = 0
        var failures = 0
        var quotaHit = false

        let waves: [[Int]] = [[0, 1, 2, 3], [4, 5, 6]]
        for wave in waves {
            // Kota bittiyse ya da üst üste çok düştüyse kalan günleri hiç
            // deneme — 3'er zaman aşımı beklemek ekranı dakikalara sürer.
            if quotaHit || failures >= 3 {
                for dayIndex in wave where collected[dayIndex] == nil {
                    if fallback.days.indices.contains(dayIndex) {
                        collected[dayIndex] = fallback.days[dayIndex]
                    }
                    planProgress = collected.count
                }
                mealPlan?.days = collected.keys.sorted().compactMap { collected[$0] }
                continue
            }
            let previous = summaryByDay.keys.sorted().compactMap { summaryByDay[$0] }

            await withTaskGroup(of: (Int, DailyMealPlan?, Bool).self) { group in
                for dayIndex in wave {
                    let rotation = rotations[dayIndex]
                    group.addTask {
                        var lastErrors: [String] = []
                        for _ in 0..<2 {
                            let json = makePlanPayloadJSON(
                                day: dayIndex, hedef: hedef, kalori: kcalTarget,
                                makrolar: makrolar, protokol: protokol,
                                alerjiler: alerjiler, sevilmeyenler: exclusions,
                                ogunSayisi: ogunSayisi, saatler: saatler,
                                previous: previous, rotasyon: rotation,
                                variation: variation, errors: lastErrors)
                            do {
                                let aiDay = try await withPlanTimeout(seconds: 60) {
                                    try await SupabaseService.shared
                                        .generateMealPlanDay(inputJSON: json)
                                }
                                let errors = validator.validate(aiDay)
                                if errors.isEmpty { return (dayIndex, aiDay, false) }
                                // Hataları modele geri ver — kör tekrar değil.
                                lastErrors = errors.map(\.description)
                            } catch {
                                // Boş plan hatası bir kez sessiz kalmıştı;
                                // AI günü neden düştü konsolda görünsün.
                                AuthLog.warn("planDay/\(dayIndex)", error)
                                let isQuota: Bool
                                if case SupabaseService.MealAnalysisError.quota = error {
                                    isQuota = true
                                } else {
                                    isQuota = false
                                }
                                return (dayIndex, nil, isQuota)
                            }
                        }
                        // İki denemede de doğrulayıcıdan geçemedi.
                        if !lastErrors.isEmpty {
                            AuthLog.warn("planDay/\(dayIndex)/validator",
                                NSError(domain: "Plan", code: 0, userInfo:
                                    [NSLocalizedDescriptionKey:
                                        lastErrors.joined(separator: " · ")]))
                        }
                        return (dayIndex, nil, false)
                    }
                }

                for await (dayIndex, aiDay, isQuota) in group {
                    if let aiDay {
                        collected[dayIndex] = Self.plannedDay(
                            from: aiDay, dayIndex: dayIndex, times: saatler)
                        summaryByDay[dayIndex] = planSummary(of: aiDay)
                        aiDayCount += 1
                    } else {
                        if isQuota { quotaHit = true }
                        failures += 1
                        if fallback.days.indices.contains(dayIndex) {
                            collected[dayIndex] = fallback.days[dayIndex]
                        }
                    }
                    planProgress = collected.count
                    mealPlan?.days = collected.keys.sorted().compactMap { collected[$0] }
                }
            }
        }

        // SON GARANTİ: hangi yoldan düşerse düşsün 7 günün 7'si de dolu
        // olmalı. Eksik gün kalmışsa yedekten tamamla.
        for dayIndex in 0..<7 where collected[dayIndex] == nil {
            if fallback.days.indices.contains(dayIndex) {
                collected[dayIndex] = fallback.days[dayIndex]
            }
        }
        planProgress = collected.count
        mealPlan?.days = collected.keys.sorted().compactMap { collected[$0] }

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
}

/// Günün ana yemek özeti — ikinci dalgaya "bunları tekrarlama" diye gidiyor.
private func planSummary(of plan: DailyMealPlan) -> DaySummaryPayload {
    let mains = plan.meals.flatMap { $0.items }
        .filter { $0.category == .anaYemek }
    return DaySummaryPayload(
        gun: plan.day.rawValue,
        ana_yemekler: mains.map(\.name),
        kirmizi_et: mains.filter { $0.proteinType == .kirmiziEt }.count,
        balik: mains.filter { $0.proteinType == .denizUrunu }.count)
}

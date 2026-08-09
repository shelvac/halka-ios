import Foundation

// MARK: - Koç sohbeti: plan kurma akışı + dürüst motivasyon (US-035)
//
// Eski koç bir tiyatroydu: "6.5 saat uyudun", "+2.15 kg", "protein %12.8"
// gibi hiçbir kaynaktan gelmeyen sayılar söylüyordu. Artık iki işi var ve
// ikisi de gerçek:
//   1. Plan kurma — sihirbaz ekranı yerine SOHBETİN İÇİNDE soru
//      yönlendirmesiyle (Simge'nin isteği). Cevaplar PlanPreferences'a
//      işlenir, üretim aynı buildWeeklyPlan'dan geçer.
//   2. Motivasyon — yalnızca gerçekten sahip olduğumuz verilerle (seri,
//      su, enerji dengesi). Veri yoksa sayı uydurmak yok.

/// Sohbet içi plan akışının durumu.
struct CoachPlanFlow: Equatable {
    enum Part: Equatable { case both, meals, workouts }
    enum Step: Equatable {
        case reuseOrFresh          // kayıtlı tercih varsa sor
        case goal
        case health                // "Yok" / "Var, yazacağım"
        case healthText            // serbest metin sağlık durumu
        case protocolPick
        case allergies             // serbest metin ya da "Yok"
        case mealsCount
        case workoutDays
        case equipment
    }
    var part: Part
    var step: Step
    var draft = PlanPreferences()
}

extension AppModel {

    // Hızlı seçenek metinleri — CoachView'daki çiplerle birebir aynı.
    static let chipFullPlan = "Haftalık planımı kur"
    static let chipMealPlan = "Sadece besin planı"
    static let chipWorkoutPlan = "Sadece antrenman planı"
    static let chipMotivation = "Motivasyon"
    static let chipRegenMeals = "Besin planını değiştir"
    static let chipRegenWorkout = "Antrenman planını değiştir"
    static let chipThanks = "Süper, teşekkürler"

    func sendCoachMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        messages.append(CoachMessage(role: .user, text: trimmed))
        coachDraft = ""
        coachTyping = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.6))
            guard let self else { return }
            let reply = self.coachReply(to: trimmed)
            self.messages.append(reply)
            self.coachTyping = false
        }
    }

    func coachReply(to text: String) -> CoachMessage {
        let lower = text.lowercased(with: Locale(identifier: "tr"))

        // Devam eden akış her şeyden önce gelir.
        if coachFlow != nil { return advanceFlow(answer: text) }

        // "Beğenmedim, başka oluştur" — kurma kontrollerinden ÖNCE:
        // "Besin planını değiştir" metni "besin + plan" içerdiği için
        // aşağıdaki bulanık eşleşmeye takılıp yanlışlıkla kurma akışını
        // başlatıyordu.
        let wantsChange = lower.contains("değiştir") || lower.contains("beğenmedim")
            || lower.contains("başka") || lower.contains("yenile")
        if wantsChange && lower.contains("besin") { return regenerate(part: .meals) }
        if wantsChange && (lower.contains("antrenman") || lower.contains("egzersiz")) {
            return regenerate(part: .workouts)
        }

        // Plan kurma girişleri
        if text == Self.chipFullPlan || lower.contains("planımı kur") {
            return startFlow(part: .both)
        }
        if text == Self.chipMealPlan || (lower.contains("besin") && lower.contains("plan")) {
            return startFlow(part: .meals)
        }
        if text == Self.chipWorkoutPlan
            || (lower.contains("antrenman") && lower.contains("plan"))
            || (lower.contains("egzersiz") && lower.contains("plan")) {
            return startFlow(part: .workouts)
        }
        if text == Self.chipThanks {
            return CoachMessage(role: .coach,
                text: "Ne demek! Planı uygulamaya başladığında öğünlerini işaretlemeyi unutma — beslenme halkan oradan doluyor.")
        }

        if lower.contains("motivasyon") || lower.contains("yorgun")
            || lower.contains("istemiyorum") || lower.contains("bırak") {
            return motivationMessage()
        }

        return CoachMessage(role: .coach,
            text: "Şunlarda yardımcı olabilirim: haftalık besin ve antrenman planı kurmak, beğenmediğin planı yenilemek, motivasyon. Aşağıdaki seçeneklerden birine dokunabilir ya da yazabilirsin.")
    }

    // MARK: Akış

    private func startFlow(part: CoachPlanFlow.Part) -> CoachMessage {
        var flow = CoachPlanFlow(part: part, step: .goal)
        if let saved = planPreferences {
            flow.draft = saved
            flow.step = .reuseOrFresh
            coachFlow = flow
            return CoachMessage(role: .ask,
                text: "Kayıtlı tercihlerin var (hedef: \(saved.goal.label.lowercased(with: Locale(identifier: "tr")))). Onlarla mı kurayım, yoksa soruları baştan mı soralım?",
                options: ["Kayıtlı tercihlerimle kur", "Soruları baştan sor"])
        }
        if part == .workouts {
            flow.step = .workoutDays
            coachFlow = flow
            return askWorkoutDays()
        }
        coachFlow = flow
        return CoachMessage(role: .ask,
            text: "Hedefin ne? Planın tamamını buna göre kuracağım.",
            options: PlanPreferences.Goal.allCases.map(\.label))
    }

    private func advanceFlow(answer: String) -> CoachMessage {
        guard var flow = coachFlow else {
            return CoachMessage(role: .coach, text: "Baştan alalım — ne yapmak istersin?")
        }
        let lower = answer.lowercased(with: Locale(identifier: "tr"))

        switch flow.step {
        case .reuseOrFresh:
            if lower.contains("kayıtlı") {
                let draft = flow.draft
                let part = flow.part
                coachFlow = nil
                return finishFlow(part: part, prefs: draft)
            }
            flow.step = flow.part == .workouts ? .workoutDays : .goal
            coachFlow = flow
            return flow.part == .workouts
                ? askWorkoutDays()
                : CoachMessage(role: .ask, text: "Hedefin ne?",
                               options: PlanPreferences.Goal.allCases.map(\.label))

        case .goal:
            if let goal = PlanPreferences.Goal.allCases.first(where: { $0.label == answer }) {
                flow.draft.goal = goal
            }
            flow.step = .health
            coachFlow = flow
            return CoachMessage(role: .ask,
                text: "Bilmem gereken bir sağlık durumun var mı? (gebelik, tansiyon, diyabet, böbrek, gut, kalp…) Bu bilgi cihazından çıkmaz; yalnızca sana uygun olmayan beslenme düzenlerini elemek için kullanılır.",
                options: ["Yok", "Var, yazacağım"])

        case .health:
            if lower.contains("yok") {
                flow.draft.healthFlags = []
                flow.step = .protocolPick
                coachFlow = flow
                return askProtocol(flags: [])
            }
            flow.step = .healthText
            coachFlow = flow
            return CoachMessage(role: .coach,
                text: "Yazabilirsin — örneğin: \"tansiyon ve gut var\".")

        case .healthText:
            let flags = Self.parseHealthFlags(answer)
            flow.draft.healthFlags = flags
            flow.step = .protocolPick
            coachFlow = flow
            return askProtocol(flags: flags)

        case .protocolPick:
            flow.draft.protocolKey = Self.protocolKey(forLabel: answer)
            flow.step = .allergies
            coachFlow = flow
            return CoachMessage(role: .ask,
                text: "Alerjin ya da yemediğin şeyler var mı? Virgülle yazabilirsin — örneğin: \"fıstık, mantar, sakatat\".",
                options: ["Yok"])

        case .allergies:
            if !lower.contains("yok") {
                let parsed = Self.parseFoodAversions(answer)
                flow.draft.allergies = parsed.allergies
                flow.draft.dislikes = parsed.dislikes
            }
            flow.step = .mealsCount
            coachFlow = flow
            return CoachMessage(role: .ask,
                text: "Günde kaç öğün yemek istersin?",
                options: ["3 öğün", "4 öğün", "5 öğün"])

        case .mealsCount:
            let count = Int(answer.prefix(1)) ?? 4
            flow.draft.mealsPerDay = count
            flow.draft.mealTimes = Self.defaultMealTimes(count)
            if flow.part == .meals {
                let draft = flow.draft
                coachFlow = nil
                return finishFlow(part: .meals, prefs: draft)
            }
            flow.step = .workoutDays
            coachFlow = flow
            return askWorkoutDays()

        case .workoutDays:
            flow.draft.workoutDays = Int(answer.prefix(1)) ?? 3
            flow.step = .equipment
            coachFlow = flow
            return CoachMessage(role: .ask,
                text: "Nerede çalışacaksın?",
                options: ["Ekipmansız", "Evde", "Salonda"])

        case .equipment:
            flow.draft.equipment = lower.contains("salon") ? .gym
                                 : lower.contains("ev") ? .home : .none
            let draft = flow.draft
            let part = flow.part
            coachFlow = nil
            return finishFlow(part: part, prefs: draft)
        }
    }

    private func askWorkoutDays() -> CoachMessage {
        CoachMessage(role: .ask,
            text: "Haftada kaç gün antrenman yapabilirsin? Dünya Sağlık Örgütü en az 2 gün kuvvet çalışması öneriyor.",
            options: ["2 gün", "3 gün", "4 gün", "5 gün"])
    }

    private func askProtocol(flags: Set<String>) -> CoachMessage {
        // Sohbette yalnızca güvenli (hekim onayı istemeyen) düzenler sunulur;
        // keto/Dukan gibi onay gerektirenler tercih ekranından seçiliyor.
        var options = ["Dengeli", "Akdeniz", "Yüksek proteinli"]
        if flags.contains("bobrek") || flags.contains("gut") || flags.contains("karaciger") {
            options.removeAll { $0 == "Yüksek proteinli" }
        }
        if flags.contains("tansiyon") { options.append("DASH (tansiyon)") }
        options.append("Sen seç")
        return CoachMessage(role: .ask,
            text: "Hangi beslenme düzenini istersin? Emin değilsen \"Sen seç\" de — durumuna en uygun olanı ben seçerim.",
            options: options)
    }

    private func finishFlow(part: CoachPlanFlow.Part, prefs: PlanPreferences) -> CoachMessage {
        planPreferences = prefs
        Task { try? await SupabaseService.shared.savePlanPreferences(prefs) }
        startGeneration(part: part, prefs: prefs, variation: 0)
        let what = part == .meals ? "besin planını"
                 : part == .workouts ? "antrenman programını" : "besin ve antrenman planını"
        return CoachMessage(role: .coach,
            text: "Harika, \(what) hazırlıyorum. Yaklaşık bir dakika sürüyor — hazır olunca buradan haber vereceğim.")
    }

    private func regenerate(part: CoachPlanFlow.Part) -> CoachMessage {
        guard let prefs = planPreferences else { return startFlow(part: part) }
        if part == .meals { planVariationMeals += 1 } else { planVariationWorkout += 1 }
        let variation = part == .meals ? planVariationMeals : planVariationWorkout
        startGeneration(part: part, prefs: prefs, variation: variation)
        return CoachMessage(role: .coach,
            text: part == .meals
                ? "Anladım, öncekinden farklı yemeklerle yeni bir besin planı kuruyorum — bir dakika."
                : "Yeni bir antrenman programı kuruyorum — bir dakika.")
    }

    private func startGeneration(part: CoachPlanFlow.Part, prefs: PlanPreferences,
                                 variation: Int) {
        // Birim testte ağa çıkma: akışın kendisi test ediliyor, üretim değil.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        let parts: Set<PlanPart> = part == .meals ? [.meals]
                                 : part == .workouts ? [.workouts] : [.meals, .workouts]
        Task { [weak self] in
            guard let self else { return }
            await self.buildWeeklyPlan(prefs, parts: parts, variation: variation)
            self.messages.append(self.planReadyMessage(part: part))
        }
    }

    func planReadyMessage(part: CoachPlanFlow.Part) -> CoachMessage {
        var lines: [String] = []
        if part != .workouts, let plan = mealPlan, !plan.days.isEmpty {
            lines.append("Beslenme: günde ortalama \(plan.averageKcal) kcal (hedef \(plan.kcalTarget)).")
        }
        if part != .meals, let workout = workoutPlan {
            lines.append("Antrenman: haftada \(workout.sessions.count) gün · \(workout.weeklyCardioMinutes) dk kardiyo.")
        }
        if planSource == "rules" {
            lines.append("Not: yapay zekâya ulaşılamadığı için plan kural tabanlı kuruldu.")
        }
        return CoachMessage(role: .planReady,
            text: lines.joined(separator: "\n"),
            title: "Haftalık planın hazır",
            options: [Self.chipRegenMeals, Self.chipRegenWorkout, Self.chipThanks])
    }

    // MARK: Motivasyon — yalnızca gerçek veri

    private func motivationMessage() -> CoachMessage {
        var lines: [String] = []
        if currentStreak > 1 {
            lines.append("Üst üste \(currentStreak) gündür buradasın — zinciri bugün de kırma.")
        }
        let waterGoal = goal(for: .water)
        if water > 0, waterGoal > 0 {
            let pct = Int(Double(water) / waterGoal * 100)
            lines.append("Su hedefinin %\(pct)'indesin" + (pct >= 100 ? " — tamamladın!" : "."))
        }
        if let average = weeklyAverageBalance, average < 0 {
            lines.append("Son günlerde ortalama \(abs(Int(average.rounded()))) kcal açık verdin; doğru yoldasın.")
        }
        if lines.isEmpty {
            lines.append("Bugün mükemmel olmak zorunda değilsin — %1 daha iyi olmak yeter. Küçük bir adımla başla: bir bardak su, on dakikalık yürüyüş.")
        }
        return CoachMessage(role: .coach, text: lines.joined(separator: " "))
    }

    // MARK: Ayrıştırıcılar

    /// Serbest metin sağlık ifadesini bayraklara çevirir.
    static func parseHealthFlags(_ text: String) -> Set<String> {
        let lower = text.lowercased(with: Locale(identifier: "tr_TR"))
        var flags = Set<String>()
        let map: [(String, [String])] = [
            ("gebelik", ["gebe", "hamile"]),
            ("emzirme", ["emzir"]),
            ("bobrek", ["böbrek"]),
            ("karaciger", ["karaciğer"]),
            ("diyabet_ilac", ["diyabet", "şeker hastal", "insülin"]),
            ("tansiyon", ["tansiyon", "hipertansiyon"]),
            ("kalp", ["kalp"]),
            ("gut", ["gut"]),
            ("tiroid", ["tiroid", "guatr"]),
            ("yeme_bozuklugu", ["yeme bozukluğu", "anoreksiya", "bulimia"])
        ]
        for (flag, keywords) in map where keywords.contains(where: lower.contains) {
            flags.insert(flag)
        }
        return flags
    }

    /// "fıstık, mantar, sakatat" → bilinen alerjiler + sevilmeyenler.
    static func parseFoodAversions(_ text: String) -> (allergies: Set<String>, dislikes: Set<String>) {
        var allergies = Set<String>(), dislikes = Set<String>()
        let allergyMap: [(String, [String])] = [
            ("Gluten", ["gluten", "çölyak"]),
            ("Laktoz", ["laktoz"]),
            ("Yumurta", ["yumurta"]),
            ("Balık", ["balık"]),
            ("Kabuklu deniz ürünü", ["karides", "midye", "kabuklu"]),
            ("Fındık/ceviz", ["fıstık", "fındık", "ceviz", "badem", "kuruyemiş"]),
            ("Soya", ["soya"]),
            ("Susam", ["susam", "tahin"])
        ]
        for piece in text.split(whereSeparator: { ",;·".contains($0) }) {
            let item = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty else { continue }
            let lower = item.lowercased(with: Locale(identifier: "tr_TR"))
            if let match = allergyMap.first(where: { $0.1.contains(where: lower.contains) }) {
                allergies.insert(match.0)
            } else {
                // Baş harfi büyüt — "mantar" ile "Mantar" iki etiket olmasın.
                let name = item.prefix(1).uppercased(with: Locale(identifier: "tr_TR"))
                    + item.dropFirst()
                dislikes.insert(String(name))
            }
        }
        return (allergies, dislikes)
    }

    static func protocolKey(forLabel label: String) -> String? {
        let lower = label.lowercased(with: Locale(identifier: "tr"))
        if lower.contains("akdeniz") { return "akdeniz" }
        if lower.contains("protein") { return "yuksek_protein" }
        if lower.contains("dash") || lower.contains("tansiyon") { return "dash" }
        if lower.contains("dengeli") { return "dengeli" }
        return nil          // "Sen seç" → üretici dengeli varsayılana düşer
    }

    static func defaultMealTimes(_ count: Int) -> [String] {
        switch count {
        case 3: return ["08:30", "13:00", "19:30"]
        case 5: return ["08:00", "11:00", "13:30", "16:30", "20:00"]
        default: return ["08:30", "13:00", "16:30", "20:00"]
        }
    }
}

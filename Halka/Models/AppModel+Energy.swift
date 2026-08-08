import Foundation

// MARK: - Enerji dengesi (US-027)

extension AppModel {

    /// Bugünün enerji dengesi.
    ///
    /// **Çift sayma tuzağı:** `Profile.tdee` = BMR × hareket çarpanı ve o
    /// çarpan egzersizi zaten içeriyor. Üstüne Apple'ın aktif enerjisini
    /// eklemek egzersizi iki kez sayar — 500-800 kcal'lik hayalî bir açık
    /// üretirdi. Bu yüzden Health bağlıyken **ölçülen** yol kullanılıyor
    /// (BMR + ölçülen aktif enerji), çarpan hiç devreye girmiyor.
    var energyToday: EnergyBalance? {
        guard let bmr = profile.bmr else { return nil }
        return EnergyBalance(intakeKcal: nutritionToday,
                             basalKcal: Int(bmr.rounded()),
                             activeKcal: hkActiveEnergy)
    }

    /// Health bağlı değilken aktif enerji ölçülemiyor; hareket düzeyi
    /// çarpanından tahmin edilir. Hangi yolun kullanıldığı ekranda yazıyor.
    var energyIsMeasured: Bool { hkConnected }

    /// Tahmini aktif enerji (Health yokken): TDEE − BMR.
    var estimatedActiveKcal: Int {
        guard let bmr = profile.bmr, let tdee = profile.tdee else { return 0 }
        return Int((tdee - bmr).rounded())
    }

    /// Ekranda gösterilen denge — ölçülen ya da tahmini yol.
    var displayedEnergy: EnergyBalance? {
        guard var balance = energyToday else { return nil }
        if !energyIsMeasured { balance.activeKcal = estimatedActiveKcal }
        return balance
    }

    // MARK: Son 7 gün

    /// Öğün kaydı olan son günlerin dengeleri (bugün dahil, yeniden eskiye).
    ///
    /// Öğün kaydı olmayan günler **atlanıyor**: Health aktarımı harcama
    /// tarafını dolduruyor ama alım tarafı boş kalıyor, o günler hesaba
    /// girse günde 2000 kcal'lik sahte bir açık çıkardı.
    var recentEnergyDays: [(date: Date, balance: EnergyBalance)] {
        guard let bmr = profile.bmr else { return [] }
        let basal = Int(bmr.rounded())
        let calendar = Self.appCalendar
        return (0..<7).compactMap { offset -> (Date, EnergyBalance)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today)
            else { return nil }
            let balance: EnergyBalance
            if offset == 0 {
                guard let today = displayedEnergy else { return nil }
                balance = today
            } else {
                guard let row = recentRings[Self.dayKeyFormatter.string(from: date)]
                else { return nil }
                balance = EnergyBalance(intakeKcal: row.nutrition_kcal,
                                        basalKcal: basal,
                                        activeKcal: row.active_energy_kcal)
            }
            guard balance.isUsable else { return nil }
            return (date, balance)
        }
    }

    /// Son 7 günün ortalama dengesi (kcal/gün).
    ///
    /// Tek günün dengesi ölçüm hatasının içinde kaybolur; anlamlı olan
    /// haftalık ortalamadır. Tahminler bu sayıdan üretiliyor.
    var weeklyAverageBalance: Double? {
        let days = recentEnergyDays
        guard !days.isEmpty else { return nil }
        return days.reduce(0.0) { $0 + Double($1.balance.balanceKcal) } / Double(days.count)
    }

    /// Tahminin gösterilip gösterilemeyeceği.
    var projectionGate: ProjectionGate {
        guard profile.isComplete, profile.bmr != nil else { return .needsProfile }
        if let age = profile.age, age < 18 { return .minor }
        let days = recentEnergyDays.count
        // Üç gün, gürültüyle sinyali ayırmak için gereken asgari örneklem.
        guard days >= 3 else { return .notEnoughDays(have: days, need: 3) }
        guard let average = weeklyAverageBalance else { return .notEnoughDays(have: days, need: 3) }
        if average >= 0 { return .gaining }
        if let bmi = profile.bmi, bmi < 18.5 { return .underweight }
        return .ready
    }

    /// Verilen gün sayısı için tahmini kilo değişimi aralığı (kg).
    func projectedChangeKg(days: Double) -> (low: Double, high: Double)? {
        guard let average = weeklyAverageBalance else { return nil }
        return WeightProjection.rangeKg(dailyBalance: average, days: days)
    }

    /// Haftalık kayıp hızı vücut ağırlığının %1'ini aşıyor mu?
    ///
    /// Sporcu beslenmesinde yaygın kabul gören üst sınır; üstünde kas kaybı
    /// ve metabolik uyum riski artıyor.
    var losingTooFast: Bool {
        guard let average = weeklyAverageBalance, average < 0,
              let weight = profile.weightKg, weight > 0 else { return false }
        return WeightProjection.weeklyRateKg(dailyBalance: average) > weight * 0.01
    }

    // MARK: Yükleme

    /// Son 7 günün kayıtları — ay gezinmesinden etkilenmeyen ayrı bir pencere.
    ///
    /// `ringHistory` görüntülenen aya bağlı; ayın başında haftanın yarısı
    /// önceki aya düşer ve ortalama sessizce eksik hesaplanırdı.
    func loadRecentRings() async {
        guard supabaseReady else { return }
        let calendar = Self.appCalendar
        guard let start = calendar.date(byAdding: .day, value: -7, to: today) else { return }
        do {
            recentRings = try await SupabaseService.shared.fetchRings(from: start, to: today)
        } catch {
            AuthLog.warn("fetchRecentRings", error)
        }
    }
}

// MARK: - Plan üretimi (US-032 · US-033)

extension AppModel {

    /// Sihirbaz tamamlanınca haftanın menüsünü ve antrenmanını kurar.
    ///
    /// Üretim tamamen istemcide ve kural tabanlı: AI çağrısı yok, maliyet yok,
    /// çevrimdışı çalışır ve hedefi tutturması garanti.
    func buildWeeklyPlan(_ prefs: PlanPreferences) async {
        planBusy = true
        defer { planBusy = false }

        let foods = await SupabaseService.shared.fetchPlanFoods()
        let exercises = await SupabaseService.shared.fetchPlanExercises()
        let protocols = await SupabaseService.shared.fetchProtocols()
        let chosen = protocols.first { $0.key == prefs.protocolKey }

        mealPlan = MealPlanGenerator.generate(
            foods: foods, prefs: prefs, protocolItem: chosen,
            kcalTarget: profile.calorieGoal ?? Int(RingKind.nutrition.goal),
            weightKg: profile.weightKg, weekStart: weekStart)

        workoutPlan = WorkoutPlanGenerator.generate(
            exercises: exercises, prefs: prefs,
            activity: profile.activityLevel, weekStart: weekStart)

        planPreferences = prefs
    }
}

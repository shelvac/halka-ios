import Foundation

// MARK: - Halkalar: gerçek tarih, kalıcılık, Apple Health (US-023 · US-024)

extension AppModel {

    /// Uygulamanın takvimi — pazartesi başlangıçlı, Türkçe.
    static var appCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "tr_TR")
        calendar.firstWeekday = 2      // Pazartesi
        return calendar
    }

    /// Gün anahtarı — sunucuya yazarken kullanılanın **aynı** örneği.
    /// İki ayrı formatlayıcı tutmak, saat dilimleri ayrıştığında verinin
    /// yanlış güne yazılmasına yol açmıştı.
    static var dayKeyFormatter: DateFormatter { SupabaseService.dayFormatter }

    var today: Date { Self.appCalendar.startOfDay(for: Date()) }

    /// Haftalık plan dizilerinde kullanılan gün indeksi (0 = Pazartesi).
    var todayWeekdayIndex: Int {
        (Self.appCalendar.component(.weekday, from: today) + 5) % 7
    }
    var todayKey: String { Self.dayKeyFormatter.string(from: today) }

    /// Görüntülenen ayın adı: "Ağustos 2026".
    var visibleMonthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: visibleMonth).capitalized(with: Locale(identifier: "tr_TR"))
    }

    var daysInVisibleMonth: Int {
        Self.appCalendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30
    }

    /// Ayın 1'inden önce ızgarada bırakılacak boşluk sayısı (pazartesi başlangıçlı).
    var leadingBlanks: Int {
        let weekday = Self.appCalendar.component(.weekday, from: visibleMonth)
        return (weekday - Self.appCalendar.firstWeekday + 7) % 7
    }

    /// Görüntülenen ay bugünün ayı mı?
    var visibleMonthIsCurrent: Bool {
        Self.appCalendar.isDate(visibleMonth, equalTo: today, toGranularity: .month)
    }

    func date(forDay day: Int) -> Date? {
        var components = Self.appCalendar.dateComponents([.year, .month], from: visibleMonth)
        components.day = day
        return Self.appCalendar.date(from: components)
    }

    func isToday(day: Int) -> Bool {
        guard let date = date(forDay: day) else { return false }
        return Self.appCalendar.isDate(date, inSameDayAs: today)
    }

    func isFuture(day: Int) -> Bool {
        guard let date = date(forDay: day) else { return false }
        return date > today
    }

    /// Bir günün halka oranları. Bugün canlı değerlerden, geçmiş günler
    /// kayıtlardan gelir. Kayıt yoksa **sıfır** — demo geçmişi uydurmuyoruz.
    func fractions(forDay day: Int) -> [Double] {
        if isToday(day: day) { return todayFractions }
        guard let date = date(forDay: day),
              let row = ringHistory[Self.dayKeyFormatter.string(from: date)] else {
            return [0, 0, 0, 0]
        }
        return [Double(row.exercise_min) / goal(for: .exercise),
                Double(row.water_ml) / goal(for: .water),
                Double(row.steps) / goal(for: .steps),
                Double(row.nutrition_kcal) / goal(for: .nutrition)]
    }

    /// Herhangi bir tarihin halka oranları (hafta şeridi bunu kullanır).
    func fractions(for date: Date) -> [Double] {
        if Self.appCalendar.isDate(date, inSameDayAs: today) { return todayFractions }
        guard let row = ringHistory[Self.dayKeyFormatter.string(from: date)] else {
            return [0, 0, 0, 0]
        }
        return [Double(row.exercise_min) / goal(for: .exercise),
                Double(row.water_ml) / goal(for: .water),
                Double(row.steps) / goal(for: .steps),
                Double(row.nutrition_kcal) / goal(for: .nutrition)]
    }

    /// İçinde bulunulan haftanın günleri (pazartesiden pazara).
    /// Eskiden ana ekranda "3-9 Ağustos" diye sabitti.
    var currentWeek: [Date] {
        let calendar = Self.appCalendar
        guard let monday = calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: today)) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// "7 Ağustos · Bugün" — detay kartının başlığı.
    func dayTitle(forDay day: Int) -> String {
        guard let date = date(forDay: day) else { return "\(day)" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM"
        let text = f.string(from: date)
        return isToday(day: day) ? text + " · Bugün" : text
    }

    /// Ana ekran başlığı: "7 Ağustos, Cuma" (eskiden sabitti).
    var todayHeaderTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: today)
    }

    /// Sosyal ekranındaki "Ağustos · halka puanı" başlığı için.
    var currentMonthName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "LLLL"
        return f.string(from: today).capitalized(with: Locale(identifier: "tr_TR"))
    }

    /// Bir günün uyku ve aktif enerjisi — halka değil, istatistik.
    /// Bugün için canlı değerler, geçmiş için kayıt kullanılır.
    func stats(forDay day: Int) -> (sleep: Double, energy: Int) {
        if isToday(day: day) { return (sleepHours, hkActiveEnergy) }
        guard let date = date(forDay: day),
              let row = ringHistory[Self.dayKeyFormatter.string(from: date)] else {
            return (0, 0)
        }
        return (row.sleep_hours, row.active_energy_kcal)
    }

    /// Bugün yapılan antrenmanlar (ana ekran).
    var todayWorkouts: [HealthKitService.WorkoutSummary] {
        hkWorkouts.filter { Self.appCalendar.isDate($0.start, inSameDayAs: today) }
    }

    /// Takvimde seçili günün antrenmanları.
    func workouts(forDay day: Int) -> [HealthKitService.WorkoutSummary] {
        guard let date = date(forDay: day) else { return [] }
        return hkWorkouts.filter { Self.appCalendar.isDate($0.start, inSameDayAs: date) }
    }

    /// Bugün dışındaki antrenmanlar, güne göre gruplanmış (yeniden eskiye).
    ///
    /// Egzersiz sekmesindeki liste düz bir akıştı: 90 günün antrenmanları
    /// arka arkaya diziliyor ve hepsi aynı güne aitmiş gibi görünüyordu.
    var pastWorkoutDays: [(date: Date, items: [HealthKitService.WorkoutSummary])] {
        let calendar = Self.appCalendar
        let past = hkWorkouts.filter { !calendar.isDate($0.start, inSameDayAs: today) }
        let grouped = Dictionary(grouping: past) { calendar.startOfDay(for: $0.start) }
        return grouped
            .map { (date: $0.key, items: $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.date > $1.date }
    }

    /// Gün başlığı: "Bugün" / "Dün" / "7 Ağustos Cuma".
    static func workoutDayTitle(_ date: Date) -> String {
        let calendar = appCalendar
        if calendar.isDateInToday(date) { return "Bugün" }
        if calendar.isDateInYesterday(date) { return "Dün" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "d MMMM EEEE" : "d MMMM yyyy"
        return f.string(from: date)
    }

    /// Üst üste kaç gündür uygulama açılıyor.
    ///
    /// Bugünden geriye doğru sayar. Bugün henüz işaretlenmemişse (kayıt
    /// yazılmadan önce) dünden başlar — kullanıcı uygulamayı açtığı anda
    /// serisinin sıfırlandığını görmesin.
    var currentStreak: Int {
        guard !visitedDays.isEmpty else { return 0 }
        let calendar = Self.appCalendar
        var day = today
        if !visitedDays.contains(Self.dayKeyFormatter.string(from: day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  visitedDays.contains(Self.dayKeyFormatter.string(from: yesterday))
            else { return 0 }
            day = yesterday
        }
        var count = 0
        while visitedDays.contains(Self.dayKeyFormatter.string(from: day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Bugünü işaretler ve seriyi yeniden hesaplar.
    func recordVisit() async {
        guard supabaseReady else { return }
        do {
            try await SupabaseService.shared.markVisited(day: today)
        } catch {
            AuthLog.warn("markVisited", error)
        }
        let start = Self.appCalendar.date(byAdding: .day, value: -400, to: today) ?? today
        visitedDays = await SupabaseService.shared.fetchVisitedDays(since: start)
    }

    /// Seçili günde hiç kayıt var mı? (boş durum metni için)
    func hasData(forDay day: Int) -> Bool {
        fractions(forDay: day).contains { $0 > 0 }
    }

    // MARK: Yükleme

    /// Görüntülenen ayın kayıtlarını çeker.
    ///
    /// Başarısız olursa `ringsLoaded` açılmaz ve hiçbir şey kaydedilmez:
    /// ağ koptuğunda "veri yok" sanıp sunucudaki kaydı sıfırla ezmek,
    /// kullanıcının günlük emeğini silmek demekti.
    func loadRingHistory() async {
        guard supabaseReady else {
            ringsLoaded = true      // demo modu: kaydetme zaten devre dışı
            return
        }
        let calendar = Self.appCalendar
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month],
                                                                      from: visibleMonth)),
              let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return }
        do {
            ringHistory = try await SupabaseService.shared.fetchRings(from: start, to: end)
        } catch {
            AuthLog.warn("fetchRings", error)
            return
        }

        // Bugünün kaydı varsa canlı değerlere yükle — uygulama kapanıp
        // açılınca su/uyku sıfırlanmasın.
        if let row = ringHistory[todayKey] {
            water = max(water, row.water_ml)
            exerciseBase = max(exerciseBase, row.exercise_min)
            sleepHours = max(sleepHours, row.sleep_hours)
            // Health bağlı değilse kayıtlı değerler gösterilsin (sıfır sanılmasın).
            if hkSteps == 0 { hkSteps = row.steps }
            if hkActiveEnergy == 0 { hkActiveEnergy = row.active_energy_kcal }
        }
        // Ancak buradan sonra yazmak güvenli.
        ringsLoaded = true
    }

    /// Kayıtlı öğün durumunu geri yükler (0010_meal_state.sql).
    ///
    /// Öğün ızgarası haftalık olduğu için kayıt da haftalık: `week_start`
    /// bu haftaya ait değilse yok sayılır, yoksa geçen haftanın işaretleri
    /// bu haftaya sızardı.
    func loadMealState() async {
        guard supabaseReady else { mealStateLoaded = true; return }
        do {
            if let row = try await SupabaseService.shared.fetchMealState() {
                // Sayaçlar hafta bağımsız: alışkanlık haftayla sıfırlanmaz.
                quickCounts = row.quick_counts ?? [:]
                if row.week_start == Self.dayKeyFormatter.string(from: weekStart) {
                    eaten = Set(row.eaten)
                    removedMeals = Set(row.removed ?? [])
                    extras = row.extras.map {
                        ExtraMeal(day: $0.day, title: $0.title, kcal: $0.kcal, time: $0.time)
                    }
                    overrides = row.overrides
                }
            }
        } catch {
            AuthLog.warn("fetchMealState", error)
            return                  // okuyamadıysak yazmıyoruz
        }
        mealStateLoaded = true
    }

    /// Gün değişimini yakalar: uygulama gece yarısını (askıda ya da açık)
    /// geçirdiyse dünün canlı değerleri yeni güne taşınmaz.
    ///
    /// "Apple Health datasını çekemiyor, dünkü etkinliği yapıyor": 00:06'da
    /// halka dünkü 81 dakikayı gösteriyor, üstelik bugünün kaydına yazıyordu.
    func rolloverDayIfNeeded() {
        let key = todayKey
        guard activeDayKey != key else { return }
        let hadPreviousDay = !activeDayKey.isEmpty
        activeDayKey = key
        // İlk kurulumda (giriş anı) temizlenecek bir "dün" yok.
        guard hadPreviousDay else { return }
        let row = ringHistory[key]     // yeni günün kaydı başka cihazdan gelmiş olabilir
        water = row?.water_ml ?? 0
        exerciseBase = row?.exercise_min ?? 0
        extraExerciseMin = 0
        sleepHours = row?.sleep_hours ?? 0
        hkSteps = row?.steps ?? 0
        hkActiveEnergy = row?.active_energy_kcal ?? 0
        // Sekmeler de yeni güne dönsün.
        mealDay = todayWeekdayIndex
        if visibleMonthIsCurrent {
            selectedCalendarDay = Self.appCalendar.component(.day, from: today)
        }
    }

    /// İçinde bulunulan haftanın pazartesisi.
    var weekStart: Date {
        let calendar = Self.appCalendar
        return calendar.date(from: calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
    }

    func persistMealState() async {
        guard supabaseReady, mealStateLoaded else { return }
        do {
            try await SupabaseService.shared.saveMealState(
                weekStart: weekStart,
                eaten: Array(eaten),
                extras: extras.map {
                    .init(day: $0.day, title: $0.title, kcal: $0.kcal, time: $0.time)
                },
                overrides: overrides,
                removed: Array(removedMeals),
                quickCounts: quickCounts)
        } catch {
            AuthLog.warn("saveMealState", error)
        }
    }

    /// Apple Health geçmişini `rings_daily`ye aktarır.
    ///
    /// Uygulama yeni kurulduğunda kullanıcının aylardır biriken Watch verisi
    /// duruyor; takvimi boş göstermek yerine son 90 günü bir kez aktarıyoruz.
    /// Beslenme aktarılmıyor — o veri Health'te değil, uygulamada tutuluyor;
    /// mevcut kayıt varsa korunur.
    func backfillFromHealthKit(days: Int = 90) async {
        // `ringHistory` okunmadan aktarım yapmak, geçmiş günlerdeki elle
        // girilmiş su/beslenme değerlerini "mevcut kayıt yok" sanıp silerdi.
        guard supabaseReady, ringsLoaded, HealthKitService.shared.isAvailable else { return }
        guard let userID = await SupabaseService.shared.currentUserID() else { return }

        let totals = await HealthKitService.shared.fetchDailyTotals(days: days)
        guard !totals.isEmpty else { return }

        let rows: [SupabaseService.RingsRow] = totals.compactMap { day, snapshot in
            guard snapshot.hasAnyData else { return nil }
            // BUGÜNÜ atla: bugünün değerleri `persistRings` ile yazılıyor ve
            // kullanıcının elle girdiklerini içeriyor. Buradan yazmak, Health'te
            // karşılığı olmayan (su, uyku) girdileri sıfırla eziyordu.
            if Self.appCalendar.isDate(day, inSameDayAs: today) { return nil }

            let key = Self.dayKeyFormatter.string(from: day)
            let existing = ringHistory[key]
            // Health'te değeri olmayan alanlarda mevcut kaydı koru — beslenme
            // zaten Health'te yok, su ve uyku da elle girilmiş olabilir.
            return SupabaseService.RingsRow(
                day: key,
                exercise_min: max(snapshot.exerciseMinutes, existing?.exercise_min ?? 0),
                water_ml: max(snapshot.waterML, existing?.water_ml ?? 0),
                sleep_hours: max(snapshot.sleepHours, existing?.sleep_hours ?? 0),
                nutrition_kcal: existing?.nutrition_kcal ?? 0,
                steps: max(snapshot.steps, existing?.steps ?? 0),
                active_energy_kcal: max(snapshot.activeEnergy, existing?.active_energy_kcal ?? 0))
        }

        do {
            try await SupabaseService.shared.saveRingsBatch(rows, userID: userID)
            healthBackfillDone = true
            await loadRingHistory()
        } catch {
            AuthLog.warn("backfillHealth", error)
        }
    }

    func showMonth(offset: Int) {
        guard let moved = Self.appCalendar.date(byAdding: .month, value: offset,
                                                to: visibleMonth) else { return }
        // Geleceğe gitmenin anlamı yok.
        if moved > today && !Self.appCalendar.isDate(moved, equalTo: today,
                                                     toGranularity: .month) { return }
        visibleMonth = moved
        selectedCalendarDay = visibleMonthIsCurrent
            ? Self.appCalendar.component(.day, from: today) : 1
        Task { await loadRingHistory() }
    }

    // MARK: Kaydetme

    /// Değişiklikleri buluta yazar — arka arkaya gelen dokunuşlarda (su ekleme
    /// gibi) her seferinde istek atmamak için 2 saniye geciktirilir.
    func scheduleRingSave() {
        ringSaveToken += 1
        let token = ringSaveToken
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.ringSaveToken == token else { return }
            await self.persistRings()
        }
    }

    func persistRings() async {
        // Okumadan yazma. Bu tek satır, açılışta bellekteki sıfırların
        // sunucudaki suyu/öğünü ezmesini engelliyor.
        guard supabaseReady, ringsLoaded else { return }
        let score = todayScore
        do {
            try await SupabaseService.shared.saveRings(
                day: today,
                exerciseMin: exerciseMinutes,
                waterML: water,
                sleepHours: sleepHours,
                nutritionKcal: nutritionToday,
                steps: hkSteps,
                activeEnergy: hkActiveEnergy,
                score: score)
            // Yerel geçmişi de tazele ki takvim anında doğru göstersin.
            ringHistory[todayKey] = SupabaseService.RingsRow(
                day: todayKey,
                exercise_min: exerciseMinutes,
                water_ml: water,
                sleep_hours: sleepHours,
                nutrition_kcal: nutritionToday,
                steps: hkSteps,
                active_energy_kcal: hkActiveEnergy,
                score: score)
        } catch {
            AuthLog.warn("saveRings", error)
        }
    }

    // MARK: Halka puanı (0034)

    /// Bugünün halka puanı — hedeflere UYUM yüzdesinden hesaplanır ki farklı
    /// hedefli arkadaşlar adil yarışsın. Liderlik tablosu bu değerin aylık
    /// toplamını okur.
    var todayScore: Int {
        Self.ringScore(exercise: exerciseMinutes, exerciseGoal: goal(for: .exercise),
                       water: water, waterGoal: goal(for: .water),
                       kcal: nutritionToday, kcalGoal: goal(for: .nutrition),
                       steps: hkSteps, stepsGoal: goal(for: .steps))
    }

    /// Günlük puan (0-110): egzersiz 30 + su 25 + beslenme 25 + adım 20,
    /// üç halka birden kapanırsa +10.
    ///
    /// Beslenme farklı: halkayı "doldurmak" değil hedef BANDINDA kalmak
    /// puan getirir (±%10 tam puan, sapma %50'ye yaklaştıkça sıfırlanır) —
    /// yoksa fazla yemek puan kazandırırdı.
    nonisolated static func ringScore(exercise: Int, exerciseGoal: Double,
                                      water: Int, waterGoal: Double,
                                      kcal: Int, kcalGoal: Double,
                                      steps: Int, stepsGoal: Double) -> Int {
        func ratio(_ value: Int, _ goal: Double) -> Double {
            goal > 0 ? min(1, Double(value) / goal) : 0
        }
        var nutrition = 0.0
        var nutritionInBand = false
        if kcal > 0, kcalGoal > 0 {
            let deviation = abs(Double(kcal) - kcalGoal) / kcalGoal
            if deviation <= 0.10 {
                nutrition = 25
                nutritionInBand = true
            } else if deviation < 0.50 {
                nutrition = 25 * (1 - (deviation - 0.10) / 0.40)
            }
        }
        var total = ratio(exercise, exerciseGoal) * 30
                  + ratio(water, waterGoal) * 25
                  + nutrition
                  + ratio(steps, stepsGoal) * 20
        if exerciseGoal > 0, Double(exercise) >= exerciseGoal,
           waterGoal > 0, Double(water) >= waterGoal, nutritionInBand {
            total += 10
        }
        return Int(total.rounded())
    }
}

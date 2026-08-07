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

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
                row.sleep_hours / goal(for: .sleep),
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
                row.sleep_hours / goal(for: .sleep),
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

    /// Sosyal ekranındaki "Ağustos · halka puanı" başlığı için.
    var currentMonthName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "LLLL"
        return f.string(from: today).capitalized(with: Locale(identifier: "tr_TR"))
    }

    /// Seçili günde hiç kayıt var mı? (boş durum metni için)
    func hasData(forDay day: Int) -> Bool {
        fractions(forDay: day).contains { $0 > 0 }
    }

    // MARK: Yükleme

    /// Görüntülenen ayın kayıtlarını çeker.
    func loadRingHistory() async {
        guard supabaseReady else { return }
        let calendar = Self.appCalendar
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month],
                                                                      from: visibleMonth)),
              let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)
        else { return }
        ringHistory = await SupabaseService.shared.fetchRings(from: start, to: end)

        // Bugünün kaydı varsa canlı değerlere yükle — uygulama kapanıp
        // açılınca su/uyku sıfırlanmasın.
        if let row = ringHistory[todayKey] {
            water = row.water_ml
            exerciseBase = row.exercise_min
            sleepHours = row.sleep_hours
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
        guard supabaseReady else { return }
        do {
            try await SupabaseService.shared.saveRings(
                day: today,
                exerciseMin: exerciseMinutes,
                waterML: water,
                sleepHours: sleepHours,
                nutritionKcal: nutritionToday)
            // Yerel geçmişi de tazele ki takvim anında doğru göstersin.
            ringHistory[todayKey] = SupabaseService.RingsRow(
                day: todayKey,
                exercise_min: exerciseMinutes,
                water_ml: water,
                sleep_hours: sleepHours,
                nutrition_kcal: nutritionToday)
        } catch {
            AuthLog.warn("saveRings", error)
        }
    }
}

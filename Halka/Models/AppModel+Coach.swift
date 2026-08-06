import Foundation

// MARK: - AI Coach conversation engine (ported from the prototype's reply logic)

extension AppModel {

    func sendCoachMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        messages.append(CoachMessage(role: .user, text: trimmed))
        coachDraft = ""
        coachTyping = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.1))
            guard let self else { return }
            let reply = self.coachReply(to: trimmed)
            if let times = reply.mealTimes { self.mealTimes = times }
            self.messages.append(reply)
            self.coachTyping = false
        }
    }

    private func coachReply(to text: String) -> CoachMessage {
        let lower = text.lowercased(with: Locale(identifier: "tr"))

        switch pending {
        case .workoutDays:
            pending = .none
            let days = lower.contains("5") ? 5 : lower.contains("4") ? 4 : 3
            return weeklyWorkoutMessage(days: days)

        case .mealGoal:
            pending = .mealTimes
            pendingMealGoal = lower.contains("kas") ? "kas" : lower.contains("koru") ? "koruma" : "kilo"
            return CoachMessage(role: .ask,
                text: "Güzel seçim. Öğün saatlerin nasıl olsun? Sırasıyla Sabah · Öğle · İkindi · Akşam — hazır seçeneklerden birini seç ya da kendi saatlerini yaz.",
                options: ["07:30 · 12:30 · 16:00 · 19:30",
                          "08:30 · 13:00 · 16:30 · 20:00",
                          "09:00 · 13:30 · 17:00 · 20:30"])

        case .mealTimes:
            pending = .none
            return weeklyMealMessage(goal: pendingMealGoal, times: parseTimes(text))

        case .none:
            break
        }

        if lower.contains("antrenman") || lower.contains("egzersiz") || lower.contains("spor") {
            pending = .workoutDays
            return CoachMessage(role: .ask,
                text: "Süper! Haftalık planını hazırlayayım — haftada kaç gün antrenmana vakit ayırabilirsin?",
                options: ["3 gün", "4 gün", "5 gün"])
        }
        if lower.contains("besin") || lower.contains("beslenme") || lower.contains("yiyeyim")
            || lower.contains("yemek") || lower.contains("öğün") || lower.contains("menü") {
            pending = .mealGoal
            return CoachMessage(role: .ask,
                text: "Haftalık besin planı için önceliğin ne? Tartı verilerine göre kalori hedefini ona göre ayarlayacağım.",
                options: ["Kilo vermek", "Korumak", "Kas kazanmak"])
        }
        if lower.contains("motivasyon") || lower.contains("yorgun") || lower.contains("istemiyorum") {
            return CoachMessage(role: .coach,
                text: "Bugün mükemmel olmak zorunda değilsin — sadece %1 daha iyi ol. 12 günlük serin var; zinciri kırma, halkayı az da olsa doldur. Kimliğini oyla: \"Ben her gün hareket eden biriyim.\"")
        }
        if lower.contains("kilo") || lower.contains("tartı") {
            return CoachMessage(role: .coach,
                text: "Son ölçümde +2.15 kg görünüyor ama kas oranın %59.8 ile mükemmel seviyede. Su oranın düşük — kilo dalgalanması büyük olasılıkla sıvı kaynaklı. Trende bak, tek ölçüme değil.")
        }
        return CoachMessage(role: .coach,
            text: "Anladım. Verilerine göre bugünkü önceliğin: su (+750 ml) ve 30 dk hareket. İstersen sana antrenman planı ya da öğün önerisi hazırlayayım.")
    }

    /// "8 13 16:30 20" or "09:00 · 13:30 · …" → four HH:mm strings.
    private func parseTimes(_ text: String) -> [String] {
        var times: [String] = []
        if let regex = try? NSRegularExpression(pattern: "\\d{1,2}[:.]\\d{2}") {
            let range = NSRange(text.startIndex..., in: text)
            times = regex.matches(in: text, range: range).compactMap {
                Range($0.range, in: text).map { String(text[$0]).replacingOccurrences(of: ".", with: ":") }
            }
        }
        if times.isEmpty, let regex = try? NSRegularExpression(pattern: "\\d{1,2}") {
            let range = NSRange(text.startIndex..., in: text)
            times = regex.matches(in: text, range: range).compactMap {
                Range($0.range, in: text).map { String(text[$0]) }
            }.map { hour in
                (hour.count == 1 ? "0" + hour : hour) + ":00"
            }
        }
        times = Array(times.prefix(4))
        if times.count < 4 { times = ["07:30", "12:30", "16:00", "19:30"] }
        return times
    }

    private func weeklyWorkoutMessage(days: Int) -> CoachMessage {
        let plan = Demo.workoutPlans[days] ?? Demo.workoutPlans[3]!
        let weekDays = Demo.dayNamesShort.enumerated().map { i, d in
            if let entry = plan[i] {
                return WeekPlanDay(day: d, title: entry.0, meta: entry.1, rest: false)
            }
            return WeekPlanDay(day: d, title: "Dinlenme", meta: "", rest: true)
        }
        return CoachMessage(role: .week,
            title: "Haftalık antrenman · \(days) gün",
            note: "Egzersiz hedefin 60 dk/gün; yürüyüşler bölge 2 temposunda. Kas oranın mükemmel — koruma odaklı.",
            weekDays: weekDays)
    }

    private func weeklyMealMessage(goal: String, times: [String]) -> CoachMessage {
        let kcal = goal == "kas" ? 1600 : goal == "koruma" ? 1500 : 1300
        let label = goal == "kas" ? "Kas kazanımı" : goal == "koruma" ? "Koruma" : "Kilo verme"
        let menuDays = Demo.dayNamesShort.enumerated().map { i, d in
            MenuPlanDay(day: d, kcal: "~\(kcal) kcal",
                        meals: Demo.mealLabels.enumerated().map { j, label in
                            MenuPlanMeal(time: times[j], label: label, food: Demo.menus[i][j])
                        })
        }
        return CoachMessage(role: .menu,
            title: "Haftalık besin planı · \(label)",
            note: "Öğün saatleri: \(times.joined(separator: " · ")). Protein oranın %12.8 (düşük) — günlük hedef 90 g protein. BMR 1420 kcal baz alındı; su hedefi 2 L.",
            menuDays: menuDays,
            mealTimes: times)
    }
}

import Foundation

// MARK: - Kural tabanlı antrenman planı (US-033)
//
// Kurallar uydurma değil, kılavuzlardan:
//   • DSÖ 2020 — haftada 150–300 dk orta şiddet aerobik + en az 2 gün,
//     tüm büyük kas gruplarına kuvvet.
//   • ACSM — her kas grubu haftada 2–3 kez, 2–4 set, 8–12 tekrar,
//     %60–80 1RM, setler arası 2–3 dk. Başlangıç 2–3 gün, orta 3, ileri 4–6.
//   • ACSM 2026 güncellemesi — hipertrofi için kas grubu başına haftada
//     ~10 set; asgari doz yok, her miktar fayda sağlıyor.

/// `exercises` tablosundan üreticinin ihtiyaç duyduğu alanlar.
struct PlanExercise: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    let nameTR: String?
    let region: String
    let equipment: String
    /// none | home | gym
    let needs: String
    let level: String
    let category: String
    let mechanic: String?

    var displayName: String { nameTR ?? name }

    enum CodingKeys: String, CodingKey {
        case id, name, region, equipment, needs, level, category, mechanic
        case nameTR = "name_tr"
    }
}

struct PlannedExercise: Identifiable, Equatable {
    let id: String
    let name: String
    let region: String
    let equipment: String
    let sets: Int
    let reps: String
    let restSeconds: Int
}

struct PlannedSession: Identifiable, Equatable {
    /// 0 = Pazartesi
    let day: Int
    let title: String
    let focus: String
    var exercises: [PlannedExercise]
    /// Seans sonuna eklenen aerobik dakikası.
    let cardioMinutes: Int
    var id: Int { day }

    /// Kaba süre: set başına ~1 dk çalışma + dinlenme, artı kardiyo ve ısınma.
    var minutes: Int {
        let strength = exercises.reduce(0) { $0 + $1.sets * (1 + $1.restSeconds / 60) }
        return strength + cardioMinutes + 10
    }
}

struct WeekWorkoutPlan: Equatable {
    var sessions: [PlannedSession]
    var weeklyCardioMinutes: Int
    /// Kas grubu → haftalık set sayısı. ACSM hacim kontrolü için.
    var weeklySets: [String: Int]
    var note: String

    var restDays: [Int] {
        let busy = Set(sessions.map(\.day))
        return (0..<7).filter { !busy.contains($0) }
    }
}

enum WorkoutPlanGenerator {

    static let push = ["Göğüs", "Omuz", "Triceps"]
    static let pull = ["Sırt", "Biceps", "Trapez"]
    static let legs = ["Ön Bacak", "Arka Bacak", "Kalça", "Baldır"]
    static let core = ["Karın", "Bel"]

    /// Haftalık bölünme — ACSM'nin gün sayısı önerilerine göre.
    ///
    /// Başlangıç seviyesinde 3 gün de tüm vücut: yeni başlayan birinde
    /// itme/çekme ayrımı gereksiz karmaşıklık, sıklık daha değerli.
    static func split(days: Int, beginner: Bool) -> [(title: String, focus: String, regions: [String])] {
        let full = ("Tüm vücut", "Tüm büyük kas grupları", push + pull + legs + core)
        switch days {
        case 2: return [full, full]
        case 3:
            if beginner { return [full, full, full] }
            return [("İtme", "Göğüs · Omuz · Triceps", push + core),
                    ("Çekme", "Sırt · Biceps", pull + core),
                    ("Bacak", "Bacak · Kalça", legs + core)]
        case 4:
            return [("Üst vücut", "Göğüs · Sırt · Omuz · Kol", push + pull),
                    ("Alt vücut", "Bacak · Kalça · Karın", legs + core),
                    ("Üst vücut", "Göğüs · Sırt · Omuz · Kol", push + pull),
                    ("Alt vücut", "Bacak · Kalça · Karın", legs + core)]
        default:
            return [("İtme", "Göğüs · Omuz · Triceps", push),
                    ("Çekme", "Sırt · Biceps", pull),
                    ("Bacak", "Bacak · Kalça", legs),
                    ("Üst vücut", "Göğüs · Sırt · Kol", push + pull),
                    ("Karın + Bacak", "Karın · Bel · Bacak", core + legs)]
        }
    }

    /// Antrenman günlerini haftaya yayar — arka arkaya yığmak toparlanmaya
    /// zaman bırakmaz.
    static func dayOffsets(_ count: Int) -> [Int] {
        switch count {
        case 2: return [0, 3]
        case 3: return [0, 2, 4]
        case 4: return [0, 1, 3, 4]
        default: return [0, 1, 2, 4, 5]
        }
    }

    static func allowedNeeds(_ equipment: PlanPreferences.Equipment) -> Set<String> {
        switch equipment {
        case .none: return ["none"]
        case .home: return ["none", "home"]
        case .gym: return ["none", "home", "gym"]
        }
    }

    /// Kullanıcıya uygun egzersiz havuzu.
    static func pool(from exercises: [PlanExercise], prefs: PlanPreferences,
                     beginner: Bool) -> [PlanExercise] {
        let needs = allowedNeeds(prefs.equipment)
        // Sakat bölgeyi çalıştırmak iyileşmeyi geciktirir; o bölge tamamen çıkar.
        let blocked = Set(prefs.injuries.flatMap { PlanPreferences.injuryBlocks[$0] ?? [] })
        return exercises.filter { item in
            guard needs.contains(item.needs) else { return false }
            guard !blocked.contains(item.region) else { return false }
            // Esneme ve pliometrik kuvvet bloğuna girmez.
            guard item.category == "Kuvvet" else { return false }
            // Yeni başlayana "İleri" seviye hareket verilmez.
            if beginner && item.level == "İleri" { return false }
            return true
        }
    }

    static func generate(exercises: [PlanExercise], prefs: PlanPreferences,
                         activity: Profile.ActivityLevel?, weekStart: Date) -> WeekWorkoutPlan {
        let beginner = (activity ?? .light) == .sedentary || (activity ?? .light) == .light
        let candidates = pool(from: exercises, prefs: prefs, beginner: beginner)
        let plans = split(days: prefs.workoutDays, beginner: beginner)
        let offsets = dayOffsets(prefs.workoutDays)

        // DSÖ: haftada en az 150 dk orta şiddet aerobik, seanslara bölünüyor.
        let cardioTotal = 150
        let perSession = max(10, Int((Double(cardioTotal) / Double(max(1, prefs.workoutDays))).rounded()))

        var rng = SeededRandom(seed: UInt64(weekStart.timeIntervalSince1970) / 86_400 &+ 7)
        var sessions: [PlannedSession] = []
        var weeklySets: [String: Int] = [:]
        // Başlangıçta 2, sonrasında 3 set — ACSM 2–4 set aralığında.
        let setCount = beginner ? 2 : 3

        for (index, plan) in plans.enumerated() {
            var picked: [PlannedExercise] = []
            var usedRegions: [String: Int] = [:]

            // Her bölgeden en az bir hareket, sonra hacme göre doldur.
            for region in plan.regions {
                guard picked.count < 6 else { break }
                let options = candidates.filter { $0.region == region }
                guard !options.isEmpty else { continue }
                // Bileşik hareketler önce: aynı sürede daha çok kas çalışır.
                let sorted = options.sorted { a, b in
                    (a.mechanic == "compound" ? 0 : 1) < (b.mechanic == "compound" ? 0 : 1)
                }
                let slice = Array(sorted.prefix(max(4, sorted.count / 2)))
                let choice = slice[rng.next(upperBound: slice.count)]
                guard !picked.contains(where: { $0.id == choice.id }) else { continue }
                picked.append(PlannedExercise(
                    id: choice.id, name: choice.displayName, region: choice.region,
                    equipment: choice.equipment, sets: setCount,
                    reps: choice.region == "Karın" || choice.region == "Bel" ? "12–15" : "8–12",
                    restSeconds: choice.mechanic == "compound" ? 120 : 90))
                usedRegions[region, default: 0] += setCount
            }

            for (region, sets) in usedRegions { weeklySets[region, default: 0] += sets }
            sessions.append(PlannedSession(
                day: offsets.indices.contains(index) ? offsets[index] : index,
                title: plan.title, focus: plan.focus,
                exercises: picked, cardioMinutes: perSession))
        }

        return WeekWorkoutPlan(
            sessions: sessions,
            weeklyCardioMinutes: perSession * sessions.count,
            weeklySets: weeklySets,
            note: "DSÖ önerisi haftada 150–300 dk orta şiddet aerobik ve en az 2 gün kuvvet. "
                + "Setler arası 90–120 sn dinlen; her hafta ya bir tekrar ya biraz ağırlık ekle.")
    }
}

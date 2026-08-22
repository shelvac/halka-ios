import Foundation

// MARK: - Navigation

enum Screen { case splash, login, register, verifyEmail, forgot, newPassword, app }
enum Tab { case home, coach, meal, workout, health }
enum HomeSegment: CaseIterable { case today, calendar, social
    var title: String {
        switch self {
        case .today: return "Bugün"
        case .calendar: return "Takvim"
        case .social: return "Arkadaşlar"
        }
    }

    /// MVP kapsamı (Simge'nin kararı): Diyetisyen pazaryeri demosu koddan
    /// tamamen çıkarıldı — lansman sonrası gerçek altyapısıyla dönerse git
    /// geçmişinden geri alınır. Arkadaşlar E7 ile gerçek oldu.
    static let mvpCases: [HomeSegment] = [.today, .calendar, .social]
}

// MARK: - Rings

/// Dört halka. Uyku yerine ADIM: uyku hedefe koşulacak bir şey değil (kimse
/// "bugün 8 saat uyumaya çalışayım" diye halka doldurmuyor, uyku olan bir şey),
/// adım ise gün içinde etkilenebilir. Uyku ölçülmeye devam ediyor ama
/// istatistik olarak gösteriliyor.
enum RingKind: CaseIterable {
    case exercise, water, steps, nutrition
    var name: String {
        switch self {
        case .exercise: return "Egzersiz"
        case .water: return "Su"
        case .steps: return "Adım"
        case .nutrition: return "Beslenme"
        }
    }
    var unit: String {
        switch self {
        case .exercise: return "dk"
        case .water: return "ml"
        case .steps: return "adım"
        case .nutrition: return "kcal"
        }
    }
    /// Profil eksikken kullanılan varsayılan hedefler.
    var goal: Double {
        switch self {
        case .exercise: return 60
        case .water: return 2000
        case .steps: return 10000
        case .nutrition: return 1420
        }
    }
}

// MARK: - Meals

struct Recipe {
    var kcal: Int
    var ingredients: [String]
    var steps: [String]
}

struct MealSelection: Equatable {
    var food: String
    var mealIndex: Int
    var fromCatalog: Bool
    var catalogName: String? = nil
}

enum MealView { case menu, log, detail, catalog, photo, market }
enum PhotoState { case idle, analyzing, done }

struct ExtraMeal: Identifiable, Equatable {
    let id = UUID()
    var day: Int
    var title: String
    var kcal: Int
    var time: String
}

// MARK: - Coach

enum CoachRole { case user, coach, ask, plan, week, menu, planReady }

struct WeekPlanDay: Identifiable {
    let id = UUID()
    var day: String
    var title: String
    var meta: String
    var rest: Bool
}

struct MenuPlanMeal: Identifiable {
    let id = UUID()
    var time: String
    var label: String
    var food: String
}

struct MenuPlanDay: Identifiable {
    let id = UUID()
    var day: String
    var kcal: String
    var meals: [MenuPlanMeal]
}

struct PlanRow: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
}

struct CoachMessage: Identifiable {
    let id = UUID()
    var role: CoachRole
    var text: String = ""
    var title: String = ""
    var note: String = ""
    var options: [String] = []
    var planRows: [PlanRow] = []
    var weekDays: [WeekPlanDay] = []
    var menuDays: [MenuPlanDay] = []
    var mealTimes: [String]? = nil
}

// MARK: - Workout

struct Exercise: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var region: String
    var reps: String

    // id yerelde üretilir, sunucuya yazılmaz (items jsonb sade kalsın).
    enum CodingKeys: String, CodingKey { case name, region, reps }
}

/// Kullanıcının kendi kurduğu program — `workout_programs` tablosunda
/// kalıcı (0030). Eskiden demo verisiydi ve uygulama kapanınca kayboluyordu.
struct WorkoutProgram: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var region: String
    var level: String
    var items: [Exercise]
}

struct ProgramDraft {
    var name = ""
    var region = "Karın"
    var level = "Başlangıç"
    var items: [Exercise] = []
}

struct WorkoutLogEntry: Identifiable {
    let id = UUID()
    var title: String
    var meta: String
}

enum WorkoutView { case home, create, library, program, run }

// MARK: - Health

struct BodyMetric: Identifiable {
    let id = UUID()
    var name: String
    var value: String
    var unit: String
    var status: String
}

struct BloodTest: Identifiable {
    let id = UUID()
    var name: String
    var value: Double
    var unit: String
    var refLow: Double
    var refHigh: Double
    /// Rapor iki uçlu referans vermediyse durum/bant gösterilmez —
    /// bilmediğimiz aralıkta "Normal" demek yanıltıcı olurdu.
    var hasRange: Bool = true
    /// Değerin geldiği rapor tarihi ("yyyy-MM-dd") — konsolide görünümde
    /// eski rapordan gelen satırlar tarihiyle işaretlenir.
    var takenAt: String = ""

    var status: String {
        guard hasRange else { return "—" }
        return value < refLow ? "Düşük" : value > refHigh ? "Yüksek" : "Normal"
    }
    /// Position of the value inside the reference band, clamped like the prototype.
    var refPosition: Double {
        min(max((value - refLow) / (refHigh - refLow), 0.02), 0.98)
    }
    var display: String {
        let s = value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(value)
        return s.replacingOccurrences(of: ".", with: ",")
    }
}

struct BloodGroup: Identifiable {
    let id = UUID()
    var name: String
    var tests: [BloodTest]
}

/// Son tahlil raporu — `blood_tests` tablosundan (PDF'ten AI ayrıştırması).
struct BloodReport {
    var takenAt: String          // en güncel raporun tarihi ("yyyy-MM-dd")
    var lab: String?
    var groups: [BloodGroup]
    /// Birleştirilen rapor (tarih) sayısı — 1'den büyükse konsolide görünüm.
    var reportCount: Int = 1

    var counts: (total: Int, ok: Int, warn: Int) {
        var ok = 0, warn = 0, total = 0
        for group in groups {
            for test in group.tests where test.hasRange {
                total += 1
                if test.status == "Normal" { ok += 1 } else { warn += 1 }
            }
        }
        return (total, ok, warn)
    }
}

/// Tahlildeki düşük değere karşılık kural tabanlı takviye önerisi.
/// Doz bilinçli olarak YOK — hekime bırakılır.
struct SupplementSuggestion: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let reason: String
}

/// Takviye/ilaç — `supplements` tablosunda kalıcı (0001 şeması).
/// `takenDates` gün anahtarları ("yyyy-MM-dd"); `taken` bugünün türevi.
struct Supplement: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var dose: String
    var time: String
    var notify: Bool
    var taken: Bool
    var takenDates: [String] = []
}

enum HealthPane { case body, blood, supplements, profile }
enum ProcessState { case idle, processing, done }

// MARK: - Social

/// İsimle arama sonucu (E7): ad + arkadaşlık durumu. Başka alan sızmaz.
struct UserSearchResult: Identifiable, Equatable {
    enum Status: String { case friend, sent, incoming, none }
    let id: UUID
    var name: String
    var username: String
    var status: Status
}

/// Bana gelen arkadaşlık isteği.
struct FriendRequest: Identifiable, Equatable {
    let id: UUID          // gönderenin kullanıcı kimliği
    var name: String
    var username: String
}

/// Arkadaşın günlük aktivite özeti (E7) — `friend_overview` RPC'sinden.
/// Yalnızca bu alanlar paylaşılır; öğün/ölçüm/tahlil asla.
struct FriendOverview: Identifiable, Equatable {
    let id: UUID
    var name: String
    var username: String = ""
    var exerciseMin: Int
    var waterML: Int
    var steps: Int
    var kcal: Int
    var activeToday: Bool
}

// MARK: - Liderlik tablosu + challenge (0034)

/// Aylık halka puanı sırası — `friend_leaderboard` RPC'sinden.
struct LeaderRow: Identifiable, Equatable {
    let id: UUID
    var name: String
    var username: String
    var points: Int
    var streak: Int
    var isMe: Bool
}

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case su, adim, egzersiz
    var id: String { rawValue }

    var label: String {
        switch self {
        case .su: return "Su"
        case .adim: return "Adım"
        case .egzersiz: return "Egzersiz"
        }
    }

    /// Günlük hedef için birim ve makul varsayılan/adım değerleri.
    var unit: String {
        switch self {
        case .su: return "ml"
        case .adim: return "adım"
        case .egzersiz: return "dk"
        }
    }
    var defaultTarget: Int {
        switch self {
        case .su: return 2000
        case .adim: return 8000
        case .egzersiz: return 30
        }
    }
    var targetStep: Int {
        switch self {
        case .su: return 250
        case .adim: return 1000
        case .egzersiz: return 5
        }
    }

    /// "2L Su · 7 Gün" tarzı otomatik başlık.
    func autoTitle(target: Int, days: Int) -> String {
        let amount: String
        switch self {
        case .su:
            amount = target % 1000 == 0
                ? "\(target / 1000)L Su"
                : String(format: "%.1fL Su", Double(target) / 1000)
                    .replacingOccurrences(of: ".", with: ",")
        case .adim:
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.locale = Locale(identifier: "tr_TR")
            amount = "\(f.string(from: NSNumber(value: target)) ?? "\(target)") Adım"
        case .egzersiz:
            amount = "\(target) dk Egzersiz"
        }
        return "\(amount) · \(days) Gün"
    }
}

struct ChallengeMemberOverview: Identifiable, Equatable {
    let id: UUID
    var name: String
    var username: String
    var status: String           // davetli / katildi
    var daysDone: Int
    var isMe: Bool
}

/// Üyesi olduğum challenge — ilerleme sunucuda rings_daily'den türetilir.
struct ChallengeOverview: Identifiable, Equatable {
    let id: UUID
    var title: String
    var kind: ChallengeKind
    var dailyTarget: Int
    var startDay: String         // "yyyy-MM-dd"
    var endDay: String
    var myStatus: String         // davetli / katildi
    var members: [ChallengeMemberOverview]

    var daysTotal: Int {
        guard let s = Self.day(startDay), let e = Self.day(endDay) else { return 0 }
        return max(0, (Calendar.current.dateComponents([.day], from: s, to: e).day ?? 0) + 1)
    }
    /// Bugün dahil kalan gün; bittiyse 0.
    var daysLeft: Int {
        guard let e = Self.day(endDay) else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        return max(0, (Calendar.current.dateComponents([.day], from: today, to: e).day ?? -1) + 1)
    }
    var isFinished: Bool { daysLeft == 0 }
    var isInvite: Bool { myStatus == "davetli" }

    private static func day(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: s)
    }
}


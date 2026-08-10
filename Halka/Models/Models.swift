import Foundation

// MARK: - Navigation

enum Screen { case splash, login, register, verifyEmail, forgot, newPassword, premium, app }
enum Role { case user, dietitian }
enum Tab { case home, coach, meal, workout, health }
enum HomeSegment: CaseIterable { case today, calendar, social, dietitian
    var title: String {
        switch self {
        case .today: return "Bugün"
        case .calendar: return "Takvim"
        case .social: return "Arkadaşlar"
        case .dietitian: return "Diyetisyen"
        }
    }
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

    var status: String {
        value < refLow ? "Düşük" : value > refHigh ? "Yüksek" : "Normal"
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

struct Supplement: Identifiable {
    let id = UUID()
    var name: String
    var dose: String
    var time: String
    var notify: Bool
    var taken: Bool
}

enum HealthPane { case body, blood, supplements, profile }
enum ProcessState { case idle, processing, done }

// MARK: - Social

struct Friend: Identifiable {
    let id = UUID()
    var name: String
    var points: Int
    var streak: Int
    var isMe: Bool = false
}

// MARK: - Dietitian marketplace

struct DietitianReview: Identifiable {
    let id = UUID()
    var name: String
    var stars: Int
    var date: String
    var text: String
}

struct Dietitian: Identifiable {
    let id = UUID()
    var name: String
    var specialty: String
    var rating: String
    var price: String
    var bio: String
    var stats: [(String, String)]
    var reviews: [DietitianReview]
    var initial: String { String(name.replacingOccurrences(of: "Dyt. ", with: "").prefix(1)) }
}

struct MyDietitian {
    var name: String
    var specialty: String
    var price: String
    var sessionsLeft: Int
    var initial: String
    var avatarIndex: Int
}

enum MarketView { case list, profile, checkout }
enum PayState { case idle, processing, done }

// MARK: - Dietitian panel (premium)

struct Client: Identifiable {
    let id = UUID()
    var name: String
    var weight: Double
    var delta: Double
    var compliance: Int
    var lastMeal: String
    var allergies: [String]
    var note: String

    var initials: String {
        name.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
    }
    var weightText: String {
        weight > 0 ? String(weight).replacingOccurrences(of: ".", with: ",") : "—"
    }
    var deltaText: String {
        weight > 0 ? "\(delta > 0 ? "+" : "")\(String(delta).replacingOccurrences(of: ".", with: ","))" + " kg" : "yeni"
    }
}

enum ClientTab: String, CaseIterable {
    case general = "Genel", body = "Vücut", blood = "Değerler", supplements = "Takviye", diet = "Diyet"
}

enum PanelView { case list, client }

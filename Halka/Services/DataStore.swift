import Foundation

// ============================================================================
// Sprint 1 — Repository katmanı iskeleti (ADR-001: MVVM + Repository)
//
// AppModel bugün demo verileriyle bellek-içi çalışıyor. Bu protokol, kalıcı
// depolamaya (Supabase, ADR-002) geçişin dikiş yeridir: AppModel'in okuma/
// yazma noktaları sprint içinde bu protokole taşınacak; InMemoryDataStore
// mevcut davranışı birebir korur, SupabaseDataStore aynı sözleşmeyi
// supabase-swift ile dolduracak (bkz. supabase/README.md).
// ============================================================================

/// `rings_daily` tablosunun satır karşılığı.
struct RingsDailyRecord: Codable, Equatable {
    var day: Date
    var exerciseMin: Int
    var waterMl: Int
    var sleepHours: Double
    var nutritionKcal: Int
}

/// `meal_logs` tablosunun satır karşılığı.
struct MealLogRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var day: Date
    var source: String        // plan | photo | manual
    var title: String
    var kcal: Int
    var loggedAt: Date
}

/// `workout_logs` tablosunun satır karşılığı.
struct WorkoutLogRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var durationMin: Int
    var doneCount: Int
    var totalCount: Int
}

/// Depolama sözleşmesi — Supabase şemasındaki çekirdek operasyonlar.
protocol DataStore {
    func loadRings(day: Date) async throws -> RingsDailyRecord?
    func saveRings(_ record: RingsDailyRecord) async throws

    func loadMealLogs(day: Date) async throws -> [MealLogRecord]
    func appendMealLog(_ record: MealLogRecord) async throws
    func deleteMealLog(id: UUID) async throws

    func loadWorkoutLogs() async throws -> [WorkoutLogRecord]
    func appendWorkoutLog(_ record: WorkoutLogRecord) async throws
}

/// Mevcut demo davranışı: her şey bellekte, uygulama kapanınca sıfırlanır.
/// (Kalıcılık istenirse ilk adım olarak bu sınıf UserDefaults/JSON'a
/// yazacak şekilde genişletilebilir — davranış sözleşmesi değişmez.)
final class InMemoryDataStore: DataStore {
    private var rings: [Date: RingsDailyRecord] = [:]
    private var mealLogs: [MealLogRecord] = []
    private var workoutLogs: [WorkoutLogRecord] = []

    func loadRings(day: Date) async throws -> RingsDailyRecord? {
        rings[Calendar.current.startOfDay(for: day)]
    }

    func saveRings(_ record: RingsDailyRecord) async throws {
        rings[Calendar.current.startOfDay(for: record.day)] = record
    }

    func loadMealLogs(day: Date) async throws -> [MealLogRecord] {
        let target = Calendar.current.startOfDay(for: day)
        return mealLogs.filter { Calendar.current.startOfDay(for: $0.day) == target }
    }

    func appendMealLog(_ record: MealLogRecord) async throws {
        mealLogs.append(record)
    }

    func deleteMealLog(id: UUID) async throws {
        mealLogs.removeAll { $0.id == id }
    }

    func loadWorkoutLogs() async throws -> [WorkoutLogRecord] {
        workoutLogs
    }

    func appendWorkoutLog(_ record: WorkoutLogRecord) async throws {
        workoutLogs.insert(record, at: 0)
    }
}

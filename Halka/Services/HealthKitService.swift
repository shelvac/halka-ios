import Foundation
import HealthKit

/// ADR-001 / Sprint 4: native HealthKit okuma — adım, egzersiz dakikası,
/// aktif enerji ve dün geceki uyku. Ekran görüntüsü + AI Koç fallback'i
/// (ProfileView'daki akış) yalnızca izin verilmediğinde anlamlıdır.
///
/// Not: HealthKit, okuma izninin verilip verilmediğini uygulamaya söylemez
/// (gizlilik gereği); bu yüzden "bağlı" durumunu veri gelip gelmediğinden
/// çıkarırız.
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    struct TodaySnapshot {
        var steps = 0
        var exerciseMinutes = 0
        var activeEnergy = 0
        var sleepHours = 0.0
        var waterML = 0

        var hasAnyData: Bool {
            steps > 0 || exerciseMinutes > 0 || activeEnergy > 0
                || sleepHours > 0 || waterML > 0
        }
    }

    /// Apple Watch'ta yapılan antrenmanın uygulamada görünen hâli.
    struct WorkoutSummary: Identifiable {
        let id: UUID
        let name: String
        let minutes: Int
        let kcal: Int
        let start: Date
    }

    private var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(),
         HKQuantityType(.stepCount),
         HKQuantityType(.appleExerciseTime),
         HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.dietaryWater),
         HKCategoryType(.sleepAnalysis)]
    }

    /// Kullanıcıya izin diyaloğunu gösterir (daha önce yanıtlandıysa sessizce döner).
    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Bugünün aktivite toplamları + dün geceki uyku süresi.
    func fetchToday() async -> TodaySnapshot {
        guard isAvailable else { return TodaySnapshot() }
        var snapshot = TodaySnapshot()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let todayPredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())

        snapshot.steps = await sum(.stepCount, unit: .count(), predicate: todayPredicate)
        snapshot.exerciseMinutes = await sum(.appleExerciseTime, unit: .minute(), predicate: todayPredicate)
        snapshot.activeEnergy = await sum(.activeEnergyBurned, unit: .kilocalorie(), predicate: todayPredicate)
        // Su: Health'te litre olarak tutulur, uygulamada ml.
        snapshot.waterML = await sum(.dietaryWater, unit: .literUnit(with: .milli),
                                     predicate: todayPredicate)

        // Uyku: önceki akşam 18:00'den şimdiye kadarki "asleep" evreleri.
        if let sleepStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) {
            let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: Date())
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
                sortDescriptors: [])
            if let samples = try? await descriptor.result(for: store) {
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let seconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                snapshot.sleepHours = (seconds / 3600 * 10).rounded() / 10
            }
        }
        return snapshot
    }

    /// Geçmiş günlerin günlük toplamları — takvimi Apple Health geçmişinden
    /// doldurmak için (US-023).
    ///
    /// Uygulama yeni kurulduğunda kullanıcının aylardır biriken Watch verisi
    /// duruyor; takvimi boş göstermek yerine buradan aktarıyoruz.
    func fetchDailyTotals(days: Int) async -> [Date: TodaySnapshot] {
        guard isAvailable, days > 0 else { return [:] }
        let calendar = Calendar.current
        let end = Date()
        guard let start = calendar.date(byAdding: .day, value: -(days - 1),
                                        to: calendar.startOfDay(for: end)) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        var result: [Date: TodaySnapshot] = [:]

        func collect(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                     assign: (inout TodaySnapshot, Int) -> Void) async {
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: .quantitySample(type: HKQuantityType(identifier),
                                           predicate: predicate),
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1))
            guard let collection = try? await descriptor.result(for: store) else { return }
            for statistics in collection.statistics() {
                guard let quantity = statistics.sumQuantity() else { continue }
                let day = calendar.startOfDay(for: statistics.startDate)
                var snapshot = result[day] ?? TodaySnapshot()
                assign(&snapshot, Int(quantity.doubleValue(for: unit).rounded()))
                result[day] = snapshot
            }
        }

        await collect(.stepCount, unit: .count()) { $0.steps = $1 }
        await collect(.appleExerciseTime, unit: .minute()) { $0.exerciseMinutes = $1 }
        await collect(.activeEnergyBurned, unit: .kilocalorie()) { $0.activeEnergy = $1 }
        await collect(.dietaryWater, unit: .literUnit(with: .milli)) { $0.waterML = $1 }

        // Uyku: uyanılan güne yazılır (gece yarısını aşan uyku bir sonraki güne ait).
        let sleepDescriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis),
                                         predicate: predicate)],
            sortDescriptors: [])
        if let samples = try? await sleepDescriptor.result(for: store) {
            let asleep: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            for sample in samples where asleep.contains(sample.value) {
                let day = calendar.startOfDay(for: sample.endDate)
                var snapshot = result[day] ?? TodaySnapshot()
                snapshot.sleepHours += sample.endDate.timeIntervalSince(sample.startDate) / 3600
                result[day] = snapshot
            }
            for (day, var snapshot) in result {
                snapshot.sleepHours = (snapshot.sleepHours * 10).rounded() / 10
                result[day] = snapshot
            }
        }
        return result
    }

    /// Bugün kaydedilen antrenmanlar (Apple Watch dahil).
    ///
    /// Egzersiz halkası `appleExerciseTime`den doluyor; bu liste ise "hangi
    /// antrenman" sorusunu cevaplıyor. Saatte egzersiz başlatıp bitirince
    /// buraya düşer.
    func fetchTodayWorkouts() async -> [WorkoutSummary] {
        guard isAvailable else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        guard let workouts = try? await descriptor.result(for: store) else { return [] }

        return workouts.map { workout in
            let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            return WorkoutSummary(
                id: workout.uuid,
                name: Self.name(for: workout.workoutActivityType),
                minutes: Int((workout.duration / 60).rounded()),
                kcal: Int(kcal.rounded()),
                start: workout.startDate)
        }
    }

    /// Apple'ın antrenman türleri için Türkçe adlar. Listede olmayan türler
    /// genel bir adla gösterilir — uydurmaktansa "Antrenman" demek yeter.
    private static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Yürüyüş"
        case .running: return "Koşu"
        case .cycling: return "Bisiklet"
        case .swimming: return "Yüzme"
        case .traditionalStrengthTraining: return "Ağırlık"
        case .functionalStrengthTraining: return "Fonksiyonel antrenman"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .cardioDance: return "Dans"
        case .elliptical: return "Eliptik"
        case .rowing: return "Kürek"
        case .stairClimbing: return "Merdiven"
        case .coreTraining: return "Karın"
        case .flexibility: return "Esneme"
        case .hiking: return "Doğa yürüyüşü"
        case .mixedCardio: return "Kardiyo"
        case .tennis: return "Tenis"
        case .basketball: return "Basketbol"
        case .soccer: return "Futbol"
        case .volleyball: return "Voleybol"
        case .boxing, .kickboxing: return "Boks"
        case .cooldown: return "Soğuma"
        default: return "Antrenman"
        }
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async -> Int {
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier), predicate: predicate),
            options: .cumulativeSum)
        guard let statistics = try? await descriptor.result(for: store),
              let quantity = statistics.sumQuantity() else { return 0 }
        return Int(quantity.doubleValue(for: unit).rounded())
    }
}

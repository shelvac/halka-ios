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

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.stepCount),
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

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async -> Int {
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier), predicate: predicate),
            options: .cumulativeSum)
        guard let statistics = try? await descriptor.result(for: store),
              let quantity = statistics.sumQuantity() else { return 0 }
        return Int(quantity.doubleValue(for: unit).rounded())
    }
}

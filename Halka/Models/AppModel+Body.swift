import Foundation
import UIKit

// MARK: - Vücut ölçümleri (US-025)

extension AppModel {

    /// En son tartım. Liste yeniden eskiye sıralı.
    var latestMeasurement: BodyMeasurement? { bodyMeasurements.first }

    /// Karşılaştırma için bir önceki tartım.
    var previousMeasurement: BodyMeasurement? {
        bodyMeasurements.count > 1 ? bodyMeasurements[1] : nil
    }

    /// Son 30 gündeki en düşük kilo — tartı uygulamalarındaki "en iyi kilo".
    var bestWeightLast30Days: Double? {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        return bodyMeasurements
            .filter { $0.measuredAt >= cutoff }
            .compactMap(\.weightKg)
            .min()
    }

    func loadBodyMeasurements() async {
        guard supabaseReady else { return }
        bodyMeasurements = await SupabaseService.shared.fetchBodyMeasurements()
        // Profildeki güncel kiloyu son tartımla hizala: iki yerde farklı sayı
        // görünmesi kafa karıştırır. YALNIZCA profil gerçekten yüklendiyse:
        // boş bir bellek profiliyle kaydetmek sunucudaki veriyi eziyordu
        // (Simge'nin doğum/boy/aktivite alanları böyle silindi).
        if profileLoaded,
           let weight = latestMeasurement?.weightKg, profile.weightKg != weight {
            profile.weightKg = weight
            var updated = profile
            updated.weightKg = weight
            try? await SupabaseService.shared.saveProfile(updated)
        }
    }

    /// Tartı ekranının fotoğrafını okur. Sonuç KAYDEDİLMEZ — önce kullanıcıya
    /// gösterilip onaylatılır; OCR yanılabilir ve yanlış sağlık verisini sessizce
    /// kaydetmek kabul edilemez.
    func readScalePhoto(_ image: UIImage) async -> BodyMeasurement {
        scaleBusy = true
        defer { scaleBusy = false }
        pendingScalePhoto = image
        return await ScaleOCR.read(image)
    }

    @discardableResult
    func saveMeasurement(_ measurement: BodyMeasurement) async -> Bool {
        bodyError = nil
        guard !measurement.isEmpty else {
            bodyError = "Hiçbir değer okunamadı — elle girip kaydedebilirsin."
            return false
        }
        guard supabaseReady else {
            bodyMeasurements.insert(measurement, at: 0)
            return true
        }

        scaleBusy = true
        defer { scaleBusy = false }
        var toSave = measurement
        do {
            // Fotoğrafı da sakla: değerin nereden geldiği sonradan doğrulanabilsin.
            if let image = pendingScalePhoto,
               let data = image.jpegData(compressionQuality: 0.7) {
                toSave.photoPath = try? await SupabaseService.shared.uploadScalePhoto(
                    data, measuredAt: toSave.measuredAt)
            }
            try await SupabaseService.shared.saveBodyMeasurement(toSave)
            pendingScalePhoto = nil
            await loadBodyMeasurements()
            return true
        } catch {
            bodyError = "Ölçüm kaydedilemedi — bağlantını kontrol edip tekrar dene."
            AuthLog.warn("saveMeasurement", error)
            return false
        }
    }

    func deleteMeasurement(_ id: UUID) async {
        guard supabaseReady else {
            bodyMeasurements.removeAll { $0.id == id }
            return
        }
        do {
            try await SupabaseService.shared.deleteBodyMeasurement(id: id)
            bodyMeasurements.removeAll { $0.id == id }
        } catch {
            bodyError = "Ölçüm silinemedi."
            AuthLog.warn("deleteMeasurement", error)
        }
    }

    /// "8 Ağustos 09:32" — ölçüm başlığı.
    static func measurementTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM HH:mm"
        return f.string(from: date)
    }

    /// Değeri ondalık sayısına göre biçimler.
    static func formatted(_ value: Double, decimals: Int) -> String {
        let text = String(format: "%.\(decimals)f", value)
        return text.replacingOccurrences(of: ".", with: ",")
    }
}

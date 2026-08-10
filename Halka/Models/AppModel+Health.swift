import Foundation
import UserNotifications

// MARK: - Health: supplements, PDF parsing simulation, Health screenshot import

extension AppModel {

    var supplementSummary: String {
        let taken = supplements.filter(\.taken).count
        let notif = supplements.filter(\.notify).count
        return "Bugün \(taken)/\(supplements.count) alındı · \(notif) hatırlatıcı açık"
    }

    func toggleSupplementTaken(_ id: UUID) {
        guard let i = supplements.firstIndex(where: { $0.id == id }) else { return }
        supplements[i].taken.toggle()
    }

    /// Bell toggle: schedules (or cancels) a real daily local notification at the dose time.
    func toggleSupplementNotify(_ id: UUID) {
        guard let i = supplements.firstIndex(where: { $0.id == id }) else { return }
        supplements[i].notify.toggle()
        let supp = supplements[i]
        let notifID = "supp-\(supp.id.uuidString)"
        let center = UNUserNotificationCenter.current()
        if supp.notify {
            Task {
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                guard granted else { return }
                let content = UNMutableNotificationContent()
                content.title = "Takviye zamanı"
                content.body = "\(supp.name) — \(supp.dose)"
                content.sound = .default
                let parts = supp.time.split(separator: ":").compactMap { Int($0) }
                var comps = DateComponents()
                comps.hour = parts.first ?? 9
                comps.minute = parts.count > 1 ? parts[1] : 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: notifID, content: content, trigger: trigger))
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [notifID])
        }
    }

    // MARK: Belgelerim — gerçek PDF yükleme (US-025)

    // Not: Vücut ölçümü için sahte PDF akışı kaldırıldı — yerini tartı
    // fotoğrafının gerçek OCR ile okunması aldı (ScaleOCR, US-025).

    func loadDocuments() async {
        documentsBusy = true
        documents = await SupabaseService.shared.listDocuments()
        documentsBusy = false
    }

    /// fileImporter'dan gelen PDF'i Storage'a yükler.
    ///
    /// Eskiden burada 2 saniyelik sahte bir "ayrıştırılıyor" animasyonu
    /// vardı; dosya hiçbir yere gitmiyordu. Artık dosya gerçekten
    /// kullanıcının RLS korumalı klasörüne kaydediliyor. Değer AYRIŞTIRMA
    /// yapılmıyor ve yapılıyormuş gibi de söylenmiyor.
    func uploadDocument(from url: URL) {
        bloodPdfError = nil
        bloodPdfName = url.lastPathComponent
        bloodPdfState = .processing
        Task { [weak self] in
            guard let self else { return }
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                guard data.count <= 10_000_000 else {
                    throw NSError(domain: "Docs", code: 1, userInfo:
                        [NSLocalizedDescriptionKey: "Dosya 10 MB'dan büyük."])
                }
                _ = try await SupabaseService.shared.uploadDocument(
                    data, filename: url.lastPathComponent)
                self.bloodPdfState = .done
                await self.loadDocuments()
            } catch {
                AuthLog.warn("uploadDocument", error)
                self.bloodPdfState = .idle
                self.bloodPdfError = "PDF yüklenemedi: \(error.localizedDescription)"
            }
        }
    }

    func deleteDocument(_ file: SupabaseService.DocumentFile) {
        documents.removeAll { $0.path == file.path }
        Task {
            try? await SupabaseService.shared.deleteDocument(path: file.path)
        }
    }

    // MARK: Elle veri girişi (US-025) — Health bağlı değilken

    /// Elle girilen günlük değerler halkalara ve `rings_daily`ye işlenir.
    /// Health bağlıyken çağrılmaz: Health tek doğru kaynak sayılır ve
    /// tazelemede elle girilenin üstüne yazar — bu yüzden giriş ekranı
    /// yalnızca Health bağlı DEĞİLKEN sunulur (çakışma sessizce çözülmez,
    /// hiç oluşmaz).
    func saveManualEntry(exerciseMin: Int?, steps: Int?, sleep: Double?) {
        if let exerciseMin { exerciseBase = max(0, exerciseMin) }
        if let steps { hkSteps = max(0, steps) }
        if let sleep { sleepHours = max(0, sleep) }
        scheduleRingSave()
    }

    // Not: "Ekran görüntüsü yükle, AI Koç okusun" akışı KALDIRILDI —
    // görüntüye bakmadan +32 dk yazan bir demoydu; gerçek veri yolları
    // (Apple Health ya da elle giriş) varken sahte aktarım kabul edilemez.

    // MARK: Blood panel summary

    var bloodCounts: (total: Int, ok: Int, warn: Int) {
        var ok = 0, warn = 0, total = 0
        for group in Demo.bloodGroups {
            for test in group.tests {
                total += 1
                if test.status == "Normal" { ok += 1 } else { warn += 1 }
            }
        }
        return (total, ok, warn)
    }
}

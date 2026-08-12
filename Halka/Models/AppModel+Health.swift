import Foundation
import UserNotifications

// MARK: - Health: supplements, PDF parsing simulation, Health screenshot import

extension AppModel {

    var supplementSummary: String {
        let taken = supplements.filter(\.taken).count
        let notif = supplements.filter(\.notify).count
        return "Bugün \(taken)/\(supplements.count) alındı · \(notif) hatırlatıcı açık"
    }

    func loadSupplements() async {
        supplements = await SupabaseService.shared.fetchSupplements()
    }

    func addSupplement(name: String, dose: String, time: String, notify: Bool) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let supplement = Supplement(name: trimmed, dose: dose, time: time,
                                    notify: false, taken: false)
        supplements.append(supplement)
        persistSupplement(supplement)
        // Bildirim izni ve planlaması mevcut zil akışından geçsin.
        if notify { toggleSupplementNotify(supplement.id) }
    }

    func deleteSupplement(_ id: UUID) {
        if let supp = supplements.first(where: { $0.id == id }), supp.notify {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["supp-\(id.uuidString)"])
        }
        supplements.removeAll { $0.id == id }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { await SupabaseService.shared.deleteSupplement(id: id) }
    }

    private func persistSupplement(_ supplement: Supplement) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else { return }
        Task { await SupabaseService.shared.saveSupplement(supplement) }
    }

    func toggleSupplementTaken(_ id: UUID) {
        guard let i = supplements.firstIndex(where: { $0.id == id }) else { return }
        supplements[i].taken.toggle()
        // Uyum geçmişi gün anahtarıyla tutulur — "bugün alındı" yarın
        // kendiliğinden sıfırlanır, geçmiş kaybolmaz.
        let today = todayKey
        if supplements[i].taken {
            if !supplements[i].takenDates.contains(today) {
                supplements[i].takenDates.append(today)
            }
        } else {
            supplements[i].takenDates.removeAll { $0 == today }
        }
        persistSupplement(supplements[i])
    }

    /// Bell toggle: schedules (or cancels) a real daily local notification at the dose time.
    func toggleSupplementNotify(_ id: UUID) {
        guard let i = supplements.firstIndex(where: { $0.id == id }) else { return }
        supplements[i].notify.toggle()
        persistSupplement(supplements[i])
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

    /// fileImporter'dan gelen PDF'i Storage'a yükler; `parseBlood` ile
    /// tahlil değerleri de Gemini'ye okutulup listeye yazılır (US-025).
    ///
    /// Ayrıştırma düşse bile dosya Belgelerim'de kalır — iki iş bağımsız.
    func uploadDocument(from url: URL, parseBlood: Bool = false) {
        bloodPdfError = nil
        bloodParseNote = nil
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
                let path = try await SupabaseService.shared.uploadDocument(
                    data, filename: url.lastPathComponent)
                await self.loadDocuments()
                if parseBlood {
                    do {
                        let count = try await SupabaseService.shared
                            .parseBloodPdf(data: data, pdfPath: path)
                        self.bloodReport = await SupabaseService.shared.fetchBloodReport()
                        self.bloodParseNote = "\(count) test değeri okundu"
                    } catch {
                        // Dosya kaydedildi; yalnızca ayrıştırma düştü.
                        self.bloodPdfError = error.localizedDescription
                    }
                }
                self.bloodPdfState = .done
            } catch {
                AuthLog.warn("uploadDocument", error)
                self.bloodPdfState = .idle
                self.bloodPdfError = "PDF yüklenemedi: \(error.localizedDescription)"
            }
        }
    }

    func loadBloodReport() async {
        bloodReport = await SupabaseService.shared.fetchBloodReport()
    }

    func deleteDocument(_ file: SupabaseService.DocumentFile) {
        documents.removeAll { $0.path == file.path }
        Task {
            try? await SupabaseService.shared.deleteDocument(path: file.path)
        }
    }

    // MARK: Elle veri girişi (US-025) — Health bağlı değilken

    /// Manuel girilen değerler günün toplamına EKLENİR, üzerine yazmaz:
    /// sabah "40 dk yürüdüm", akşam "20 dk koştum" → 60 dk. (Negatif değer
    /// yanlış girişi düzeltmek içindir; toplam sıfırın altına inmez.)
    ///
    /// Health bağlıyken çağrılmaz: Health tek doğru kaynak sayılır ve
    /// tazelemede girilenin üstüne yazar — bu yüzden giriş ekranı yalnızca
    /// Health bağlı DEĞİLKEN sunulur (çakışma sessizce çözülmez, hiç oluşmaz).
    func saveManualEntry(exerciseMin: Int?, steps: Int?, sleep: Double?) {
        if let exerciseMin { exerciseBase = max(0, exerciseBase + exerciseMin) }
        if let steps { hkSteps = max(0, hkSteps + steps) }
        if let sleep { sleepHours = max(0, sleep) }
        scheduleRingSave()
    }

    // Not: "Ekran görüntüsü yükle, AI Koç okusun" akışı KALDIRILDI —
    // görüntüye bakmadan +32 dk yazan bir demoydu; gerçek veri yolları
    // (Apple Health ya da elle giriş) varken sahte aktarım kabul edilemez.

    // Not: sahte "16 test değeri" özeti kaldırıldı (bloodCounts) — değer
    // ayrıştırma gelene dek ekran dürüst boş durumda.
}

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

    // MARK: PDF upload simulations

    func processBodyPdf(named name: String) {
        bodyPdfName = name
        bodyPdfState = .processing
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            self?.bodyPdfState = .done
        }
    }

    func processBloodPdf(named name: String) {
        bloodPdfName = name
        bloodPdfState = .processing
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            self?.bloodPdfState = .done
        }
    }

    /// Apple Health screenshot fallback: AI Koç parses the image and credits the exercise ring.
    func processHealthScreenshot() {
        healthShotState = .processing
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard let self else { return }
            self.healthShotState = .done
            self.extraExerciseMin += 32
        }
    }

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

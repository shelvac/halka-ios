import Foundation

// MARK: - Social, dietitian marketplace, premium dietitian panel

extension AppModel {

    // MARK: Social

    /// Leaderboard: friends + the user, ranked by ring points.
    // Not: demo leaderboard/challenge ve sahte arkadaş ekleme kaldırıldı —
    // Arkadaşlar artık gerçek (E7): arkadaş kodu + friend_overview RPC.
    // Gerçek akışlar AppModel+Social.swift'te.

    // MARK: Marketplace

    func openDietitianProfile(_ index: Int) {
        selectedDietitian = index
        marketView = .profile
        payState = .idle
    }

    func marketBack() {
        marketView = marketView == .checkout ? .profile : .list
        payState = .idle
    }

    func payNow() {
        payState = .processing
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            self?.payState = .done
        }
    }

    func activateDietitian() {
        let d = Demo.dietitians[selectedDietitian]
        myDietitian = MyDietitian(name: d.name, specialty: d.specialty, price: d.price,
                                  sessionsLeft: 8, initial: d.initial,
                                  avatarIndex: selectedDietitian)
        marketView = .list
        payState = .idle
    }

    func dropDietitian() {
        myDietitian = nil
    }

    // MARK: Panel — clients

    var currentClient: Client? {
        clients.indices.contains(selectedClient) ? clients[selectedClient] : nil
    }

    var clientStats: (count: String, avg: String, loss: String) {
        let avg = clients.isEmpty ? 0
            : clients.map(\.compliance).reduce(0, +) / clients.count
        return ("\(clients.count)", "%\(avg)", "-1,3 kg")
    }

    func addClient() {
        let name = clientNameDraft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        clients.append(Client(name: name, weight: 0, delta: 0, compliance: 0,
                              lastMeal: "Henüz kayıt yok — davet gönderildi",
                              allergies: [], note: ""))
        clientNameDraft = ""
    }

    func openClient(_ index: Int) {
        selectedClient = index
        clientTab = .general
        panelView = .client
        dietPlan = nil
        dietSent = false
        dietDay = 0
    }

    func addAllergy() {
        let value = allergyDraft.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, clients.indices.contains(selectedClient) else { return }
        clients[selectedClient].allergies.append(value)
        allergyDraft = ""
    }

    func removeAllergy(at index: Int) {
        guard clients.indices.contains(selectedClient),
              clients[selectedClient].allergies.indices.contains(index) else { return }
        clients[selectedClient].allergies.remove(at: index)
    }

    // MARK: Panel — synthetic per-client detail data (index-based, as in the prototype)

    func clientBodyRows(_ client: Client) -> [(String, String, String, String)] {
        let i = selectedClient
        let w = client.weight > 0 ? client.weight : 70
        let bmi = w / (1.66 * 1.66)
        func fmt(_ v: Double) -> String {
            String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
        }
        return [
            ("Ağırlık", String(w).replacingOccurrences(of: ".", with: ","), "kg", w > 80 ? "Yüksek" : "Normal"),
            ("BMI", fmt(bmi), "", bmi > 25 ? "Yüksek" : "Normal"),
            ("Yağ", "\(28 + i * 4)", "%", i < 2 ? "Yüksek" : "Normal"),
            ("İskelet Kası", "\(34 + i * 2)", "%", "Mükemmel"),
            ("Su", "\(48 + i)", "%", "Normal"),
            ("Metabolizma (BMR)", "\(1350 + i * 90)", "kcal/gün", "Normal"),
            ("Viseral Yağ", "\(6 + i * 2)", "", i == 1 ? "Yüksek" : "Sağlıklı"),
            ("Metabolik Yaş", "\(34 + i * 4)", "", "Normal")
        ]
    }

    func clientBloodRows() -> [(String, String, String, String)] {
        let i = selectedClient
        return [
            ("Açlık Glukozu", "\(84 + i * 8)", "mg/dl", i == 1 ? "Yüksek" : "Normal"),
            ("TSH", String(format: "%.2f", 1.9 + Double(i) * 0.9).replacingOccurrences(of: ".", with: ","), "uIU/mL", "Normal"),
            ("Hemoglobin", String(format: "%.1f", 13.8 - Double(i) * 1.1).replacingOccurrences(of: ".", with: ","), "g/dL", i == 2 ? "Düşük" : "Normal"),
            ("D Vitamini", "\(16 + i * 6)", "ng/mL", i == 0 ? "Düşük" : "Normal"),
            ("B12", "\(190 + i * 90)", "pg/mL", i == 0 ? "Düşük" : "Normal"),
            ("Ferritin", "\(12 + i * 14)", "ng/mL", i == 2 ? "Düşük" : "Normal")
        ]
    }

    var clientBloodNote: String {
        switch selectedClient {
        case 0: return "D vitamini ve B12 düşük — takviye planına eklendi, 3 ay sonra kontrol tahlili önerilir."
        case 1: return "Açlık glukozu sınırda — rafine karbonhidrat kısıtlaması ve akşam yürüyüşü önerildi."
        default: return "Ferritin ve hemoglobin düşük — demir takviyesi C vitamini ile birlikte, çay/kahve araları açık."
        }
    }

    /// 4-week weight trend bars ending at current weight.
    func clientTrend(_ client: Client) -> [(String, Double)] {
        let w = client.weight > 0 ? client.weight : 70
        let weights = [w + 1.7, w + 1.1, w + 0.5, w]
        return weights.enumerated().map { i, v in
            (i == 3 ? "Bu hafta" : "H-\(3 - i)", v)
        }
    }

    // MARK: Panel — diet program + allergy conflicts

    var activeDietPlan: [[String]] {
        dietPlan ?? Demo.menus
    }

    func setDietMeal(day: Int, slot: Int, text: String) {
        var plan = activeDietPlan
        plan[day][slot] = text
        dietPlan = plan
        dietSent = false
    }

    /// Allergens from the client's list found in a meal description.
    func allergyHits(meal: String, client: Client?) -> [String] {
        guard let client, !client.allergies.isEmpty, !meal.isEmpty else { return [] }
        let m = meal.lowercased(with: Locale(identifier: "tr"))
        return client.allergies.filter { allergy in
            let a = allergy.lowercased(with: Locale(identifier: "tr"))
            let expanded = Demo.allergenKeys
                .filter { a.contains($0.key) }
                .flatMap(\.value)
            let words = expanded.isEmpty ? [a] : expanded
            return words.contains { m.contains($0) }
        }
    }

    /// All week-wide conflicts: (day label · meal label — allergens).
    var allergyWarnings: [String] {
        guard let client = currentClient else { return [] }
        var out: [String] = []
        for (di, day) in activeDietPlan.enumerated() {
            for (mi, meal) in day.enumerated() {
                let hits = allergyHits(meal: meal, client: client)
                if !hits.isEmpty {
                    out.append("\(Demo.dayNamesShort[di]) · \(Demo.mealLabels[mi]) — \(hits.joined(separator: ", "))")
                }
            }
        }
        return out
    }

    func sendDietProgram() {
        dietSent = true
    }

    var dietSentText: String {
        guard let client = currentClient else { return "" }
        let first = client.name.split(separator: " ").first.map(String.init) ?? client.name
        return "Haftalık program \(first)'ya gönderildi · hedef \(dietKcalTarget) kcal/gün"
    }
}

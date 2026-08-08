import SwiftUI

// MARK: - Plan sihirbazı (US-030)
//
// Tercihleri profil ekranına gömmek yerine plan kurulurken adım adım
// soruyoruz: cevaplar planın nasıl kurulacağını doğrudan belirliyor ve
// bağlamı içinde sorulduğunda anlamlı oluyor.
//
// Sağlık taraması üçüncü adımdan ÖNCE geliyor — uygun olmayan protokol
// kullanıcıya hiç gösterilmiyor. "Seçtin ama sana uygun değil" demek,
// baştan göstermemekten kötü.

struct PlanWizardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var step: PlanWizardStep = .goal
    @State private var prefs = PlanPreferences()
    @State private var protocols: [DietProtocol] = []
    @State private var loading = true
    @State private var saving = false
    @State private var doctorConfirmed = false

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                progressBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(step.title)
                            .font(.h(21))
                            .foregroundStyle(Color.ink)
                            .kerning(-0.4)
                        Text(step.subtitle)
                            .font(.h(12, .semibold))
                            .foregroundStyle(Color.sub)
                            .fixedSize(horizontal: false, vertical: true)
                        content
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
                footer
            }
        }
        .task {
            protocols = await SupabaseService.shared.fetchProtocols()
            if let saved = await SupabaseService.shared.fetchPlanPreferences() { prefs = saved }
            if prefs.mealTimes.count != prefs.mealsPerDay { syncMealTimes() }
            loading = false
        }
    }

    // MARK: Çerçeve

    private var header: some View {
        HStack {
            Button {
                if let previous = PlanWizardStep(rawValue: step.rawValue - 1) {
                    withAnimation(.easeInOut(duration: 0.2)) { step = previous }
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: step == .goal ? "xmark" : "chevron.left")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color.sub)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Planımı oluştur")
                .font(.h(14))
                .foregroundStyle(Color.ink)
            Spacer()
            Text("\(step.rawValue + 1)/\(PlanWizardStep.allCases.count)")
                .font(.h(11, .bold))
                .foregroundStyle(Color.faint)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.hairline2)
                Capsule().fill(Color.coral)
                    .frame(width: geo.size.width
                           * Double(step.rawValue + 1) / Double(PlanWizardStep.allCases.count))
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 18)
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let blocker = blockingMessage {
                Text(blocker)
                    .font(.h(11, .bold))
                    .foregroundStyle(Color.warnOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                if step == .review { save() } else { advance() }
            } label: {
                Text(step == .review ? (saving ? "Kaydediliyor…" : "Tercihlerimi kaydet")
                                     : "Devam")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .coralButton()
            .opacity(canAdvance ? 1 : 0.45)
            .disabled(!canAdvance || saving)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(Color.bgApp)
    }

    // MARK: Adımlar

    @ViewBuilder
    private var content: some View {
        switch step {
        case .goal:     goalStep
        case .health:   healthStep
        case .diet:     dietStep
        case .food:     foodStep
        case .meals:    mealsStep
        case .workout:  workoutStep
        case .review:   reviewStep
        }
    }

    private var goalStep: some View {
        VStack(spacing: 10) {
            ForEach(PlanPreferences.Goal.allCases) { goal in
                selectableCard(title: goal.label, detail: goal.detail,
                               selected: prefs.goal == goal) {
                    prefs.goal = goal
                }
            }
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            chipCloud(PlanPreferences.healthOptions.map(\.label),
                      selected: Set(PlanPreferences.healthOptions
                        .filter { prefs.healthFlags.contains($0.key) }.map(\.label))) { label in
                guard let option = PlanPreferences.healthOptions.first(where: { $0.label == label })
                else { return }
                toggle(option.key, in: &prefs.healthFlags)
            }
            Text("Bu bilgi yalnızca sana uygun olmayan beslenme düzenlerini elemek için kullanılır. Hiçbir yere gönderilmez.")
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dietStep: some View {
        VStack(spacing: 10) {
            if loading {
                SpinnerArc(size: 24).frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if eligibleProtocols.isEmpty {
                infoBox("Belirttiğin sağlık durumlarıyla güvenle önerebileceğimiz kısıtlayıcı bir düzen yok. Dengeli beslenme ve hekim takibi en doğrusu.")
            }
            ForEach(eligibleProtocols) { item in
                protocolCard(item)
            }
            if hiddenCount > 0 {
                Text("\(hiddenCount) düzen, belirttiğin sağlık durumlarına uygun olmadığı için gösterilmiyor.")
                    .font(.h(10.5, .bold))
                    .foregroundStyle(Color.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let chosen = selectedProtocol, chosen.needsDoctor {
                doctorConsent(chosen)
            }
        }
    }

    private var foodStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldTitle("Beslenme tarzı")
            HStack(spacing: 8) {
                ForEach(PlanPreferences.DietStyle.allCases) { style in
                    chip(style.label, on: prefs.dietStyle == style) { prefs.dietStyle = style }
                }
            }
            fieldTitle("Alerji veya intolerans")
            chipCloud(PlanPreferences.allergyOptions, selected: prefs.allergies) {
                toggle($0, in: &prefs.allergies)
            }
            fieldTitle("Sevmediklerin")
            chipCloud(PlanPreferences.dislikeOptions, selected: prefs.dislikes) {
                toggle($0, in: &prefs.dislikes)
            }
        }
    }

    private var mealsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldTitle("Günde kaç öğün?")
            HStack(spacing: 8) {
                ForEach([3, 4, 5], id: \.self) { count in
                    chip("\(count) öğün", on: prefs.mealsPerDay == count) {
                        prefs.mealsPerDay = count
                        syncMealTimes()
                    }
                }
            }
            fieldTitle("Öğün saatleri")
            VStack(spacing: 0) {
                ForEach(Array(prefs.mealTimes.enumerated()), id: \.offset) { i, time in
                    HStack {
                        Text(Self.mealLabel(i, of: prefs.mealsPerDay))
                            .font(.h(12.5, .bold))
                            .foregroundStyle(Color.inkMid)
                        Spacer()
                        Text(time)
                            .font(.h(14))
                            .foregroundStyle(Color.coral)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .card(16)

            fieldTitle("Haftada kaç gün dışarıda yiyorsun?")
            HStack(spacing: 8) {
                ForEach([0, 1, 2, 3], id: \.self) { days in
                    chip(days == 0 ? "Hiç" : "\(days) gün",
                         on: prefs.eatingOutDays == days) { prefs.eatingOutDays = days }
                }
            }
        }
    }

    private var workoutStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldTitle("Haftada kaç gün antrenman?")
            HStack(spacing: 8) {
                ForEach([2, 3, 4, 5], id: \.self) { days in
                    chip("\(days) gün", on: prefs.workoutDays == days) { prefs.workoutDays = days }
                }
            }
            // DSÖ 2020: haftada 150-300 dk orta şiddet aerobik + 2 gün kuvvet.
            Text("Dünya Sağlık Örgütü haftada en az 2 gün kuvvet çalışması öneriyor.")
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)

            fieldTitle("Nerede çalışacaksın?")
            VStack(spacing: 10) {
                ForEach(PlanPreferences.Equipment.allCases) { option in
                    selectableCard(title: option.label, detail: option.detail,
                                   selected: prefs.equipment == option) {
                        prefs.equipment = option
                    }
                }
            }

            fieldTitle("Ağrıyan veya sakatlanmış bölge")
            chipCloud(PlanPreferences.injuryOptions, selected: prefs.injuries) {
                toggle($0, in: &prefs.injuries)
            }
        }
    }

    private var reviewStep: some View {
        VStack(spacing: 12) {
            targetCard
            summaryCard
            if let chosen = selectedProtocol {
                if let warning = chosen.warning {
                    infoBox(warning, tone: .warnOrange, background: .warnOrangeBg)
                }
                if let phases = chosen.phases, !phases.isEmpty {
                    phaseCard(phases)
                }
            }
            // Plan üreticisi henüz yazılmadı; olmayan bir şeyi vaat etmiyoruz.
            infoBox("Tercihlerin kaydedilecek. Haftalık besin ve antrenman programını üreten kısım sıradaki adım.")
        }
    }

    // MARK: Kartlar

    private var targetCard: some View {
        let kcal = targetKcal
        let macros = selectedProtocol?.macros(kcal: kcal, weightKg: model.profile.weightKg)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(kcal)")
                    .font(.h(30))
                    .foregroundStyle(Color.coral)
                    .kerning(-0.8)
                Text("kcal/gün")
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.sub)
                Spacer()
            }
            if let macros {
                HStack(spacing: 0) {
                    macroCell("Protein", macros.protein, .coral)
                    divider
                    macroCell("Karbonhidrat", macros.carb, .waterBlue)
                    divider
                    macroCell("Yağ", macros.fat, .warnOrange)
                }
            }
            Text(model.profile.bmr == nil
                 ? "Profilin eksik olduğu için varsayılan hedef kullanıldı."
                 : "Mifflin-St Jeor ile hesaplandı; hedef hiçbir zaman bazal metabolizmanın altına inmiyor.")
                .font(.h(10, .bold))
                .foregroundStyle(Color.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(width: 1, height: 28)
    }

    private func macroCell(_ label: String, _ grams: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(grams) g")
                .font(.h(14))
                .foregroundStyle(color)
            Text(label)
                .font(.h(9.5, .bold))
                .foregroundStyle(Color.sub)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow("Hedef", prefs.goal.label)
            summaryRow("Beslenme düzeni", selectedProtocol?.name ?? "Seçilmedi")
            summaryRow("Tarz", prefs.dietStyle.label)
            summaryRow("Öğün", "\(prefs.mealsPerDay) öğün · \(prefs.mealTimes.joined(separator: " · "))")
            if !prefs.allergies.isEmpty {
                summaryRow("Alerji", prefs.allergies.sorted().joined(separator: ", "))
            }
            if !prefs.dislikes.isEmpty {
                summaryRow("Sevmedikleri", prefs.dislikes.sorted().joined(separator: ", "))
            }
            summaryRow("Antrenman", "\(prefs.workoutDays) gün · \(prefs.equipment.label)")
            if !prefs.injuries.isEmpty {
                summaryRow("Dikkat", prefs.injuries.sorted().joined(separator: ", "))
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .card(18)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.h(11.5, .bold))
                .foregroundStyle(Color.sub)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .font(.h(12, .semibold))
                .foregroundStyle(Color.inkBody)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }

    private func phaseCard(_ phases: [DietProtocol.Phase]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evreler")
                .font(.h(13))
                .foregroundStyle(Color.ink)
            ForEach(Array(phases.enumerated()), id: \.offset) { i, phase in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.h(11, .bold))
                        .foregroundStyle(Color.coral)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.coralBg))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(phase.ad) · \(phase.sure)")
                            .font(.h(12, .bold))
                            .foregroundStyle(Color.inkBody)
                        Text(phase.aciklama)
                            .font(.h(11, .semibold))
                            .foregroundStyle(Color.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private func protocolCard(_ item: DietProtocol) -> some View {
        let selected = prefs.protocolKey == item.key
        return Button {
            prefs.protocolKey = item.key
            doctorConfirmed = false
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(item.name)
                        .font(.h(14))
                        .foregroundStyle(Color.ink)
                    evidenceBadge(item.evidence)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.coral)
                    }
                }
                Text(item.summary)
                    .font(.h(11.5, .semibold))
                    .foregroundStyle(Color.sub)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                // Kanıtın ne kadar sağlam olduğunu saklamıyoruz.
                if selected, let note = item.evidenceNote {
                    Text(note)
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.faint)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                if selected {
                    HStack(spacing: 6) {
                        macroTag("K", item.carbPct, .waterBlue)
                        macroTag("Y", item.fatPct, .warnOrange)
                        if let perKg = item.proteinPerKg {
                            Text("P \(Self.decimal(perKg)) g/kg")
                                .font(.h(10, .bold))
                                .foregroundStyle(Color.coral)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Color.coralBg))
                        } else {
                            macroTag("P", item.proteinPct, .coral)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.coralBg.opacity(0.55) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Color.coral : .clear, lineWidth: 1.5)
            )
            .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func macroTag(_ letter: String, _ pct: Double, _ color: Color) -> some View {
        Text("\(letter) %\(Int(pct.rounded()))")
            .font(.h(10, .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func evidenceBadge(_ evidence: String) -> some View {
        let colors: (Color, Color) = switch evidence {
        case "güçlü": (.greenDark, .greenBg)
        case "orta": (.blueDark, .blueBg)
        case "gelişmekte": (.warnOrange, .warnOrangeBg)
        default: (.coralDark, .coralBg)
        }
        return Text("kanıt: \(evidence)")
            .font(.h(9.5, .bold))
            .foregroundStyle(colors.0)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(colors.1))
    }

    private func doctorConsent(_ item: DietProtocol) -> some View {
        Button { doctorConfirmed.toggle() } label: {
            HStack(alignment: .top, spacing: 10) {
                RoundCheck(on: doctorConfirmed)
                Text("\(item.name) düzenini hekimimle konuştum ve benim için uygun olduğunu biliyorum.")
                    .font(.h(11.5, .semibold))
                    .foregroundStyle(Color.inkBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.warnOrangeBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Küçük parçalar

    private func fieldTitle(_ text: String) -> some View {
        Text(text)
            .font(.h(13))
            .foregroundStyle(Color.ink)
    }

    private func selectableCard(title: String, detail: String, selected: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.h(14))
                        .foregroundStyle(Color.ink)
                    Text(detail)
                        .font(.h(11, .semibold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Color.coral : Color.chevron)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.coralBg.opacity(0.55) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color.coral : .clear, lineWidth: 1.5)
            )
            .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func chip(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.h(12, .bold))
                .foregroundStyle(on ? .white : Color.inkMid)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(on ? Color.coral : Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.ink.opacity(0.05), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func chipCloud(_ options: [String], selected: Set<String>,
                           action: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                chip(option, on: selected.contains(option)) { action(option) }
            }
        }
    }

    private func infoBox(_ text: String, tone: Color = .sub,
                         background: Color = .bgField) -> some View {
        Text(text)
            .font(.h(11.5, .semibold))
            .foregroundStyle(tone)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Mantık

    /// Kullanıcının sağlık bayraklarıyla çelişmeyen protokoller.
    private var eligibleProtocols: [DietProtocol] {
        protocols.filter { item in
            item.contraindications.allSatisfy { !prefs.healthFlags.contains($0) }
        }
    }

    private var hiddenCount: Int { protocols.count - eligibleProtocols.count }

    private var selectedProtocol: DietProtocol? {
        protocols.first { $0.key == prefs.protocolKey }
    }

    /// Hedef kalori profilden; protokol bunu değiştirmiyor, yalnızca
    /// makro dağılımını belirliyor.
    private var targetKcal: Int {
        model.profile.calorieGoal ?? Int(RingKind.nutrition.goal)
    }

    private var canAdvance: Bool {
        switch step {
        case .diet:
            guard let chosen = selectedProtocol else { return false }
            return chosen.needsDoctor ? doctorConfirmed : true
        default:
            return true
        }
    }

    private var blockingMessage: String? {
        guard step == .diet else { return nil }
        if selectedProtocol == nil { return "Devam etmek için bir beslenme düzeni seç." }
        if let chosen = selectedProtocol, chosen.needsDoctor, !doctorConfirmed {
            return "Bu düzen için hekim onayını işaretlemen gerekiyor."
        }
        return nil
    }

    private func advance() {
        guard let next = PlanWizardStep(rawValue: step.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = next }
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        // Sağlık bayrağı değişince seçili protokol uygunsuz hâle gelebilir.
        if let chosen = selectedProtocol,
           chosen.contraindications.contains(where: { prefs.healthFlags.contains($0) }) {
            prefs.protocolKey = nil
            doctorConfirmed = false
        }
    }

    /// Öğün sayısı değişince saatleri gün içine yeniden dağıtır.
    private func syncMealTimes() {
        let presets: [Int: [String]] = [
            3: ["08:30", "13:00", "19:30"],
            4: ["08:30", "13:00", "16:30", "20:00"],
            5: ["08:00", "11:00", "13:30", "16:30", "20:00"]
        ]
        prefs.mealTimes = presets[prefs.mealsPerDay] ?? presets[4]!
    }

    private func save() {
        saving = true
        Task {
            try? await SupabaseService.shared.savePlanPreferences(prefs)
            model.planPreferences = prefs
            saving = false
            dismiss()
        }
    }

    private static func mealLabel(_ index: Int, of total: Int) -> String {
        let four = ["Kahvaltı", "Öğle", "Ara öğün", "Akşam"]
        let three = ["Kahvaltı", "Öğle", "Akşam"]
        let five = ["Kahvaltı", "Ara öğün", "Öğle", "Ara öğün", "Akşam"]
        let labels = total == 3 ? three : total == 5 ? five : four
        return index < labels.count ? labels[index] : "Öğün \(index + 1)"
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

import SwiftUI

/// US-026 — İlk giriş karşılama akışı.
///
/// Profili eksik kullanıcıya, doğrulama sonrası uygulama açılır açılmaz
/// gösterilir. Her adım TEK soru sorar; geri dönülebilir. Her cevap anında
/// buluta yazılır (kısmî kayıt güvenli — boş alan sunucuda hiçbir şeyi
/// ezmez), bu yüzden akış yarıda kesilirse uygulama yeniden açıldığında
/// KALINAN adımdan sürer. Profil tamamlanınca (`profile_completed_at`)
/// bir daha gösterilmez. Hiçbir adımda sahte/varsayılan veri yazılmaz:
/// "Devam" ancak kullanıcı cevap verince aktifleşir.
enum OnboardingStep: Int, CaseIterable {
    case username, birth, sex, body, target, activity, health

    /// Kaldığı yerden devam: ilk eksik alanın adımı.
    static func firstIncomplete(for profile: Profile) -> OnboardingStep {
        if profile.username.isEmpty { return .username }
        if profile.birthDate == nil { return .birth }
        if profile.sex == nil { return .sex }
        if profile.heightCm == nil || profile.weightKg == nil { return .body }
        if profile.targetWeightKg == nil { return .target }
        if profile.activityLevel == nil { return .activity }
        return .health
    }

    var title: String {
        switch self {
        case .username: return "Kullanıcı adını seç"
        case .birth: return "Doğum tarihin?"
        case .sex: return "Cinsiyetin?"
        case .body: return "Boyun ve kilon?"
        case .target: return "Hedef kilon?"
        case .activity: return "Günlük hareketin?"
        case .health: return "Apple Health'i bağlayalım mı?"
        }
    }

    var subtitle: String {
        switch self {
        case .username: return "Arkadaşların seni bu adla bulur — benzersizdir, sonra da değiştirilebilir."
        case .birth: return "Kalori ve hedef hesapları yaşına göre yapılır."
        case .sex: return "Bazal metabolizma formülü cinsiyete göre değişir."
        case .body: return "Halkaların ve planların temeli bu iki sayı."
        case .target: return "Enerji dengesi ve haftalık planlar hedefe göre kurulur."
        case .activity: return "Günlük kalori hedefini hareket düzeyin belirler."
        case .health: return "Adım, egzersiz ve uyku halkalara kendiliğinden işlenir. İstersen sonra da bağlayabilirsin."
        }
    }
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var step: OnboardingStep = .birth
    @State private var birthDate = Calendar.current.date(
        from: DateComponents(year: 1995, month: 1, day: 1)) ?? Date()
    @State private var birthTouched = false
    @State private var sex: Profile.Sex? = nil
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var targetText = ""
    @State private var activity: Profile.ActivityLevel? = nil
    @State private var fieldError: String? = nil
    @State private var usernameText = ""
    /// nil = kontrol edilmedi/ediliyor; true/false = uygunluk sonucu.
    @State private var usernameAvailable: Bool? = nil
    @State private var claiming = false

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(step.title)
                            .font(.h(24))
                            .foregroundStyle(Color.ink)
                            .kerning(-0.5)
                        Text(step.subtitle)
                            .font(.h(12.5, .semibold))
                            .foregroundStyle(Color.sub)
                            .lineSpacing(3)
                            .padding(.bottom, 16)
                        stepContent
                        if let fieldError {
                            Text(fieldError)
                                .font(.h(11.5, .semibold))
                                .foregroundStyle(Color.coralDark)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                }
                footer
            }
        }
        .onAppear {
            // Kalınan adımdan devam; girilmiş alanlar geri doldurulur.
            step = OnboardingStep.firstIncomplete(for: model.profile)
            usernameText = model.profile.username
            if let date = model.profile.birthDate { birthDate = date; birthTouched = true }
            sex = model.profile.sex
            if let h = model.profile.heightCm { heightText = String(Int(h)) }
            if let w = model.profile.weightKg { weightText = Self.trim(w) }
            if let t = model.profile.targetWeightKg { targetText = Self.trim(t) }
            activity = model.profile.activityLevel
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if step != OnboardingStep.allCases.first, step.rawValue > 0 {
                Button {
                    fieldError = nil
                    step = OnboardingStep(rawValue: step.rawValue - 1) ?? .birth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.inkMid)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            // İlerleme noktaları — kaçıncı sorudayız.
            HStack(spacing: 5) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.coral : Color.hairline2)
                        .frame(width: s == step ? 18 : 7, height: 7)
                }
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .username:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("@")
                        .font(.h(16))
                        .foregroundStyle(Color.sub)
                    TextField("kullaniciadi", text: $usernameText)
                        .font(.h(15))
                        .foregroundStyle(Color.ink)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)

                if !usernameText.isEmpty {
                    if !SupabaseService.isValidUsername(usernameText) {
                        Text("3-20 karakter; küçük harf, rakam, nokta ve alt çizgi.")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.sub)
                    } else if usernameAvailable == false {
                        Text("Bu kullanıcı adı alınmış — başka bir ad dene.")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.coralDark)
                    } else if usernameAvailable == true {
                        Text("Uygun ✓")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.greenDark)
                    }
                }
            }
            .task(id: usernameText) {
                usernameAvailable = nil
                guard SupabaseService.isValidUsername(usernameText) else { return }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                usernameAvailable = await SupabaseService.shared
                    .usernameAvailable(usernameText)
            }
        case .birth:
            DatePicker("", selection: $birthDate,
                       in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "tr_TR"))
                .frame(maxWidth: .infinity)
                .onChange(of: birthDate) { birthTouched = true }
                .card(18)
        case .sex:
            VStack(spacing: 8) {
                ForEach(Profile.Sex.allCases) { option in
                    choiceRow(option.label, selected: sex == option) { sex = option }
                }
            }
        case .body:
            VStack(spacing: 10) {
                numberField("Boy", unit: "cm", text: $heightText, placeholder: "165")
                numberField("Kilo", unit: "kg", text: $weightText, placeholder: "62,5")
            }
        case .target:
            VStack(spacing: 10) {
                numberField("Hedef kilo", unit: "kg", text: $targetText, placeholder: "58")
                Button {
                    if let current = parse(weightText) { targetText = Self.trim(current) }
                } label: {
                    Text("Kilomu korumak istiyorum")
                        .font(.h(12, .bold))
                        .foregroundStyle(Color.coral)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        case .activity:
            VStack(spacing: 8) {
                ForEach(Profile.ActivityLevel.allCases) { option in
                    choiceRow(option.label, detail: option.detail,
                              selected: activity == option) { activity = option }
                }
            }
        case .health:
            VStack(spacing: 10) {
                Button {
                    model.connectHealthKit()
                    finish()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                        Text("Apple Health'i Bağla")
                    }
                    .font(.h(14))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.coral)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                Button { finish() } label: {
                    Text("Şimdilik atla")
                        .font(.h(12.5, .bold))
                        .foregroundStyle(Color.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        Group {
            if step != .health {
                Button { advance() } label: {
                    Text("Devam").frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .coralButton()
                .disabled(!stepAnswered)
                .opacity(stepAnswered ? 1 : 0.5)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }

    /// "Devam" yalnızca cevap verilince — sahte/varsayılan veri yazılmaz.
    private var stepAnswered: Bool {
        switch step {
        case .username: return SupabaseService.isValidUsername(usernameText)
                            && usernameAvailable != false && !claiming
        case .birth: return birthTouched
        case .sex: return sex != nil
        case .body: return parse(heightText) != nil && parse(weightText) != nil
        case .target: return parse(targetText) != nil
        case .activity: return activity != nil
        case .health: return true
        }
    }

    private func advance() {
        fieldError = nil
        // Kullanıcı adı benzersizliği sunucuda kesinleşir — başarıda ilerlenir.
        if step == .username {
            claiming = true
            Task {
                defer { claiming = false }
                if let error = await model.claimUsername(usernameText) {
                    fieldError = error
                } else {
                    step = .birth
                }
            }
            return
        }
        var draft = model.profile
        switch step {
        case .username:
            break
        case .birth:
            draft.birthDate = birthDate
        case .sex:
            draft.sex = sex
        case .body:
            guard let height = parse(heightText), (100...250).contains(height) else {
                fieldError = "Boy 100-250 cm aralığında olmalı."; return
            }
            guard let weight = parse(weightText), (30...300).contains(weight) else {
                fieldError = "Kilo 30-300 kg aralığında olmalı."; return
            }
            draft.heightCm = height
            draft.weightKg = weight
        case .target:
            guard let target = parse(targetText), (30...300).contains(target) else {
                fieldError = "Hedef kilo 30-300 kg aralığında olmalı."; return
            }
            draft.targetWeightKg = target
        case .activity:
            draft.activityLevel = activity
        case .health:
            break
        }
        // Her adım anında buluta yazılır — yarıda kesilirse kalınan yerden.
        Task { await model.saveProfile(draft) }
        step = OnboardingStep(rawValue: step.rawValue + 1) ?? .health
    }

    private func finish() {
        var draft = model.profile
        if draft.completedAt == nil { draft.completedAt = Date() }
        Task { await model.saveProfile(draft) }
        model.showOnboarding = false
    }

    // MARK: Küçük parçalar

    private func choiceRow(_ label: String, detail: String? = nil,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.h(13.5))
                        .foregroundStyle(Color.ink)
                    if let detail {
                        Text(detail)
                            .font(.h(10.5, .semibold))
                            .foregroundStyle(Color.sub)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? Color.coral : Color.chevron)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(selected ? Color.coralBg : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func numberField(_ label: String, unit: String,
                             text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.h(13, .bold))
                .foregroundStyle(Color.inkBody)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.h(16))
                .foregroundStyle(Color.ink)
                .frame(width: 110)
            Text(unit)
                .font(.h(11, .bold))
                .foregroundStyle(Color.sub)
                .frame(width: 28, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
    }

    private func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

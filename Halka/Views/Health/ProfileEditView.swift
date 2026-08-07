import PhotosUI
import SwiftUI

/// US-016 — Profil düzenleme.
///
/// Girilen değerler hem profil kartını hem **halka hedeflerini** besliyor
/// (kalori, su, egzersiz, uyku). Bu yüzden ekranın altında hesaplanan hedefler
/// canlı gösteriliyor: kullanıcı "boyumu yazınca ne değişiyor" sorusunun
/// cevabını kaydetmeden görüyor.
///
/// Not: SwiftUI `Form` yerine uygulamanın kendi kart/alan dili kullanılıyor —
/// `Form` iOS'un standart gri liste görünümünü getiriyor ve tasarımdan kopuyor.
struct ProfileEditView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Profile()
    @State private var hasBirthDate = false
    @State private var birthDate = Calendar.current.date(
        byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var targetText = ""
    @State private var saving = false
    @State private var photoItem: PhotosPickerItem? = nil
    @FocusState private var focused: Field?

    private enum Field { case name, height, weight, target }

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        avatarPicker
                        identityCard
                        measuresCard
                        activityCard
                        goalsCard
                        if let error = model.profileError { errorBanner(error) }
                        saveButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Başlık

    private var header: some View {
        HStack {
            Button("Vazgeç") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.sub)
            Spacer()
            Text("Profilim")
                .font(.h(16))
                .foregroundStyle(Color.ink)
            Spacer()
            // Simetri için görünmez ikiz — başlık tam ortada kalsın.
            Text("Vazgeç").font(.h(13)).opacity(0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: Fotoğraf

    /// Fotoğrafa dokununca galeri açılır. Fotoğraf yoksa baş harf avatarı
    /// gösterilir; kamera ikonu dokunulabilir olduğunu belli eder.
    private var avatarPicker: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images,
                         photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(image: model.avatarImage,
                                  fullName: draft.fullName.isEmpty
                                      ? model.userFullName : draft.fullName,
                                  size: 92)

                    Circle()
                        .fill(Color.coral)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: model.profileBusy ? "arrow.triangle.2.circlepath"
                                                                : "camera.fill")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().strokeBorder(Color.bgApp, lineWidth: 3))
                }
            }
            .buttonStyle(.plain)
            .disabled(model.profileBusy)

            if model.avatarImage == nil {
                Text("Fotoğraf ekle")
                    .font(.h(12))
                    .foregroundStyle(Color.coral)
            } else {
                Button("Fotoğrafı kaldır") {
                    Task { await model.removeAvatar() }
                }
                .font(.h(12))
                .foregroundStyle(Color.sub)
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await model.updateAvatar(image)
                }
                photoItem = nil
            }
        }
    }

    // MARK: Kartlar

    private var identityCard: some View {
        card("Kimlik") {
            fieldRow("Ad Soyad") {
                TextField("Adın", text: $draft.fullName)
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.ink)
                    .textContentType(.name)
                    .multilineTextAlignment(.trailing)
                    .focused($focused, equals: .name)
            }

            divider
            HStack {
                Text("Doğum tarihi")
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.inkBody)
                Spacer()
                if hasBirthDate {
                    DatePicker("", selection: $birthDate, in: ...Date(),
                               displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Color.coral)
                } else {
                    Button("Ekle") { hasBirthDate = true }
                        .font(.h(12.5))
                        .foregroundStyle(Color.coral)
                }
            }
            .padding(.vertical, 12)

            divider
            VStack(alignment: .leading, spacing: 10) {
                Text("Cinsiyet")
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.inkBody)
                chipRow(Profile.Sex.allCases, selected: draft.sex, label: \.label) { sex in
                    draft.sex = (draft.sex == sex) ? nil : sex
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var measuresCard: some View {
        card("Ölçüler") {
            measureRow("Boy", text: $heightText, unit: "cm", field: .height)
            divider
            measureRow("Güncel kilo", text: $weightText, unit: "kg", field: .weight)
            divider
            measureRow("Hedef kilo", text: $targetText, unit: "kg", field: .target)
        }
    }

    private var activityCard: some View {
        card("Hareket düzeyi") {
            VStack(spacing: 8) {
                ForEach(Profile.ActivityLevel.allCases) { level in
                    activityRow(level)
                }
            }
            .padding(.vertical, 12)

            Text("Günlük kalori hedefin bu seçime göre hesaplanır.")
                .font(.h(11, .semibold))
                .foregroundStyle(Color.faint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
        }
    }

    private func activityRow(_ level: Profile.ActivityLevel) -> some View {
        let selected = draft.activityLevel == level
        return Button {
            draft.activityLevel = selected ? nil : level
        } label: {
            HStack(spacing: 10) {
                RoundCheck(on: selected, size: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(level.label)
                        .font(.h(12.5))
                        .foregroundStyle(Color.ink)
                    Text(level.detail)
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? Color.coralBg : Color.bgField)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Hesaplanan hedefler — profil eksikse neyin eksik olduğunu söyler.
    private var goalsCard: some View {
        let preview = previewProfile
        return card("Hesaplanan hedeflerin") {
            if preview.isComplete {
                VStack(spacing: 0) {
                    goalRow("Günlük kalori", preview.calorieGoal.map { "\($0) kcal" }, .green)
                    divider
                    goalRow("Su", preview.waterGoalML.map { "\($0) ml" }, .waterBlue)
                    divider
                    goalRow("Egzersiz", "\(preview.exerciseGoalMin) dk", .coral)
                    divider
                    goalRow("Uyku", String(format: "%.1f sa", preview.sleepGoalHours), .sleepPurple)
                    if let bmi = preview.bmi, let label = preview.bmiLabel {
                        divider
                        goalRow("BMI", String(format: "%.1f · %@", bmi, label), .ink)
                    }
                }

                Text("Kalori hedefi Mifflin-St Jeor formülüyle hesaplanır ve asla "
                     + "bazal metabolizmanın altına inmez.")
                    .font(.h(10.5, .semibold))
                    .foregroundStyle(Color.faint)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                Text("Hedeflerin hesaplanması için doğum tarihi, cinsiyet, boy ve "
                     + "güncel kilo gerekiyor.")
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.coralNote)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.coralBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.vertical, 12)
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                if saving { ProgressView().tint(.white) }
                Text(saving ? "Kaydediliyor…" : "Kaydet")
            }
            .coralButton()
        }
        .buttonStyle(.plain)
        .disabled(saving)
        .padding(.top, 4)
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.h(12, .semibold))
            .foregroundStyle(Color.warnDeep)
            .lineSpacing(3)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.warnFieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Yapı taşları

    private func card<Content: View>(_ title: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.h(11, .bold))
                .foregroundStyle(Color.sub)
                .kerning(0.3)
                .padding(.top, 14)
                .padding(.bottom, 2)
            content()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(height: 1)
    }

    private func fieldRow<Content: View>(_ title: String,
                                         @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.h(13, .bold))
                .foregroundStyle(Color.inkBody)
            Spacer()
            content()
        }
        .padding(.vertical, 13)
    }

    private func measureRow(_ title: String, text: Binding<String>,
                            unit: String, field: Field) -> some View {
        fieldRow(title) {
            HStack(spacing: 5) {
                TextField("—", text: text)
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.ink)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70)
                    .focused($focused, equals: field)
                Text(unit)
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.sub)
                    .frame(width: 24, alignment: .leading)
            }
        }
    }

    private func goalRow(_ title: String, _ value: String?, _ color: Color) -> some View {
        HStack {
            Text(title)
                .font(.h(12.5, .bold))
                .foregroundStyle(Color.inkBody)
            Spacer()
            Text(value ?? "—")
                .font(.h(14))
                .foregroundStyle(color)
        }
        .padding(.vertical, 12)
    }

    /// Tek seçimli yatay çip satırı.
    private func chipRow<T: Identifiable & Equatable>(
        _ items: [T], selected: T?, label: (T) -> String, tap: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                let on = selected == item
                Button { tap(item) } label: {
                    Text(label(item))
                        .font(.h(11.5))
                        .foregroundStyle(on ? Color.white : Color.inkBody)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(on ? Color.coral : Color.bgField)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Durum

    /// Metin alanları henüz `draft`e işlenmediği için önizleme ayrı üretilir.
    private var previewProfile: Profile {
        var p = draft
        p.birthDate = hasBirthDate ? birthDate : nil
        p.heightCm = Self.number(heightText)
        p.weightKg = Self.number(weightText)
        p.targetWeightKg = Self.number(targetText)
        return p
    }

    private func load() {
        draft = model.profile
        if draft.fullName.isEmpty { draft.fullName = model.userFullName }
        if let date = model.profile.birthDate {
            birthDate = date
            hasBirthDate = true
        }
        heightText = Self.text(model.profile.heightCm)
        weightText = Self.text(model.profile.weightKg)
        targetText = Self.text(model.profile.targetWeightKg)
    }

    private func save() {
        focused = nil
        saving = true
        let updated = previewProfile
        Task {
            let ok = await model.saveProfile(updated)
            saving = false
            if ok { dismiss() }
        }
    }

    // MARK: Sayı biçimlendirme
    //
    // Türkçe klavyede ondalık ayırıcı virgül; iki biçimi de kabul ediyoruz.

    private static func number(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        return value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

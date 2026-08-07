import SwiftUI

/// US-016 — Profil düzenleme.
///
/// Girilen değerler hem profil kartını hem **halka hedeflerini** besliyor
/// (kalori, su, egzersiz, uyku). Bu yüzden ekranın altında hesaplanan hedefler
/// canlı gösteriliyor: kullanıcı "boyumu yazınca ne değişiyor" sorusunun
/// cevabını kaydetmeden görüyor.
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Kimlik") {
                    TextField("Ad Soyad", text: $draft.fullName)
                        .textContentType(.name)

                    Toggle("Doğum tarihi", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("Tarih", selection: $birthDate,
                                   in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }

                    Picker("Cinsiyet", selection: $draft.sex) {
                        Text("Seçilmedi").tag(Profile.Sex?.none)
                        ForEach(Profile.Sex.allCases) { sex in
                            Text(sex.label).tag(Profile.Sex?.some(sex))
                        }
                    }
                }

                Section("Ölçüler") {
                    measureRow("Boy", text: $heightText, unit: "cm")
                    measureRow("Güncel kilo", text: $weightText, unit: "kg")
                    measureRow("Hedef kilo", text: $targetText, unit: "kg")
                }

                Section {
                    Picker("Hareket düzeyi", selection: $draft.activityLevel) {
                        Text("Seçilmedi").tag(Profile.ActivityLevel?.none)
                        ForEach(Profile.ActivityLevel.allCases) { level in
                            Text(level.label).tag(Profile.ActivityLevel?.some(level))
                        }
                    }
                    if let level = draft.activityLevel {
                        Text(level.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Hareket")
                } footer: {
                    Text("Günlük kalori hedefin bu seçime göre hesaplanır.")
                }

                goalsSection

                if let error = model.profileError {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Color.coralDark)
                    }
                }
            }
            .navigationTitle("Profilim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(saving)
                }
            }
            .onAppear(perform: load)
        }
    }

    /// Hesaplanan hedefler — profil eksikse neyin eksik olduğunu söyler.
    @ViewBuilder
    private var goalsSection: some View {
        let preview = previewProfile
        Section {
            if preview.isComplete {
                goalRow("Günlük kalori", preview.calorieGoal.map { "\($0) kcal" })
                goalRow("Su", preview.waterGoalML.map { "\($0) ml" })
                goalRow("Egzersiz", "\(preview.exerciseGoalMin) dk")
                goalRow("Uyku", String(format: "%.1f sa", preview.sleepGoalHours))
                if let bmi = preview.bmi, let label = preview.bmiLabel {
                    goalRow("BMI", String(format: "%.1f · %@", bmi, label))
                }
            } else {
                Text("Hedeflerin hesaplanması için doğum tarihi, cinsiyet, boy ve "
                     + "güncel kilo gerekiyor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Hesaplanan hedeflerin")
        } footer: {
            if preview.isComplete {
                Text("Kalori hedefi Mifflin-St Jeor formülüyle hesaplanır ve asla "
                     + "bazal metabolizmanın altına inmez.")
            }
        }
    }

    private func goalRow(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "—")
                .foregroundStyle(.secondary)
        }
    }

    private func measureRow(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
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

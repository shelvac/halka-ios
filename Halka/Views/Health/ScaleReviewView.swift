import SwiftUI

/// US-025 — Fotoğraftan okunan değerlerin onay ekranı.
///
/// OCR yanılabilir. Yanlış bir sağlık verisini sessizce kaydetmek kabul
/// edilemez, bu yüzden okunan her değer kaydetmeden önce burada gösteriliyor
/// ve düzeltilebiliyor. Okunamayan alanlar boş kalıyor — uydurulmuyor.
struct ScaleReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// Fotoğraftan okunan (veya elle girilecek) ölçüm.
    @State var measurement: BodyMeasurement
    /// Elle giriş mi, fotoğraftan mı geldi?
    var fromPhoto: Bool

    @State private var editingField: BodyMeasurement.Field? = nil

    private var readCount: Int {
        measurement.fields.filter { $0.value != nil }.count
    }

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 12) {
                        if fromPhoto { summaryBanner }
                        fieldsCard
                        if let error = model.bodyError { errorBanner(error) }
                        saveButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(item: $editingField) { field in
            MeasurePickerSheet(
                title: field.label,
                unit: field.unit.isEmpty ? "" : field.unit,
                range: Self.range(for: field),
                allowsDecimal: field.decimals > 0,
                value: Binding(
                    get: { measurement.fields.first { $0.id == field.id }?.value },
                    set: { measurement.setValue($0, forField: field.id) }))
        }
    }

    private var header: some View {
        HStack {
            Button("Vazgeç") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.sub)
            Spacer()
            Text(fromPhoto ? "Okunan değerler" : "Ölçüm ekle")
                .font(.h(16))
                .foregroundStyle(Color.ink)
            Spacer()
            Text("Vazgeç").font(.h(13)).opacity(0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    /// Kaç değerin okunduğunu açıkça söyler — "hepsini aldı" sanılmasın.
    private var summaryBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: readCount > 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(readCount > 0 ? Color.green : Color.warnOrange)
            Text(readCount > 0
                 ? "\(readCount) değer okundu. Kaydetmeden önce kontrol et; "
                   + "yanlış okunanı düzeltebilirsin."
                 : "Fotoğraftan değer okunamadı. Alanlara dokunup elle girebilirsin.")
                .font(.h(11.5, .semibold))
                .foregroundStyle(Color.inkBody)
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(readCount > 0 ? Color.greenBg : Color.warnOrangeBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(measurement.fields.enumerated()), id: \.element.id) { i, field in
                Button { editingField = field } label: {
                    HStack(spacing: 10) {
                        Text(field.label)
                            .font(.h(12.5, .bold))
                            .foregroundStyle(Color.inkBody)
                        Spacer()
                        if let value = field.value {
                            Text(AppModel.formatted(value, decimals: field.decimals))
                                .font(.h(14))
                                .foregroundStyle(Color.ink)
                        } else {
                            Text("—")
                                .font(.h(14))
                                .foregroundStyle(Color.faint)
                        }
                        if !field.unit.isEmpty {
                            Text(field.unit)
                                .font(.h(11, .bold))
                                .foregroundStyle(Color.sub)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.chevron)
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .card(18)
    }

    private var saveButton: some View {
        Button {
            Task {
                if await model.saveMeasurement(measurement) { dismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                if model.scaleBusy { ProgressView().tint(.white) }
                Text(model.scaleBusy ? "Kaydediliyor…" : "Kaydet")
            }
            .coralButton()
        }
        .buttonStyle(.plain)
        .disabled(model.scaleBusy || measurement.isEmpty)
        .opacity(measurement.isEmpty ? 0.5 : 1)
        .padding(.top, 4)
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.h(12, .semibold))
            .foregroundStyle(Color.warnDeep)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.warnFieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Her alanın makul aralığı — seçicide anlamsız değerler dolaşmasın.
    private static func range(for field: BodyMeasurement.Field) -> ClosedRange<Int> {
        switch field.id {
        case "weight", "leanMass", "muscleMass": return 20...250
        case "bmi": return 10...60
        case "bmr": return 500...4000
        case "metabolicAge": return 10...100
        case "boneMass": return 1...10
        case "visceralFat": return 1...60
        case "fatMass", "skeletalMuscleKg", "waterMass": return 1...150
        default: return 0...100          // yüzdeler
        }
    }
}

extension BodyMeasurement.Field: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

import SwiftUI

/// US-016 — Boy/kilo için tekerlek seçici.
///
/// Elle yazmak yerine seçtiriyoruz: klavyeden sayı girmek hem yavaş hem hatalı
/// (virgül/nokta karışıklığı, "172,5" yerine "1725" gibi kazalar). Tekerlek
/// hem geçersiz değeri baştan imkânsız kılıyor hem tek elle kullanılıyor.
///
/// Kilo iki tekerlekli: tam kısım + ondalık. Tek tekerlekte 0,1 adımla
/// 30-250 arası 2200 satır olurdu; kaydırması işkence.
struct MeasurePickerSheet: View {
    let title: String
    let unit: String
    let range: ClosedRange<Int>
    let allowsDecimal: Bool
    /// Seçenek yoksa ("—") boş bırakılabilsin diye opsiyonel.
    @Binding var value: Double?

    @Environment(\.dismiss) private var dismiss
    @State private var whole: Int = 0
    @State private var decimal: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Vazgeç") { dismiss() }
                    .font(.h(13))
                    .foregroundStyle(Color.sub)
                Spacer()
                Text(title)
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                Spacer()
                Button("Seç") {
                    value = allowsDecimal
                        ? Double(whole) + Double(decimal) / 10
                        : Double(whole)
                    dismiss()
                }
                .font(.h(13))
                .foregroundStyle(Color.coral)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            HStack(spacing: 0) {
                Picker("", selection: $whole) {
                    ForEach(Array(range), id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: allowsDecimal ? 110 : 150)

                if allowsDecimal {
                    Text(",")
                        .font(.h(20))
                        .foregroundStyle(Color.ink)
                    Picker("", selection: $decimal) {
                        ForEach(0..<10, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 80)
                }

                Text(unit)
                    .font(.h(15))
                    .foregroundStyle(Color.sub)
                    .padding(.leading, 6)
            }
            .padding(.top, 4)

            if value != nil {
                Button("Temizle") {
                    value = nil
                    dismiss()
                }
                .font(.h(12))
                .foregroundStyle(Color.sub)
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }
        }
        .background(Color.bgApp)
        .presentationDetents([.height(allowsDecimal ? 340 : 320)])
        .onAppear(perform: load)
    }

    /// Mevcut değer yoksa makul bir orta noktadan başla — kullanıcı en baştan
    /// uzun uzun kaydırmasın.
    private func load() {
        let current = value ?? Double(defaultStart)
        whole = min(max(Int(current), range.lowerBound), range.upperBound)
        decimal = Int(((current - Double(Int(current))) * 10).rounded())
        if decimal > 9 { decimal = 9 }
    }

    private var defaultStart: Int {
        allowsDecimal ? 70 : 170
    }
}

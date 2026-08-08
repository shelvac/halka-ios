import SwiftUI

// MARK: - Enerji dengesi (US-027)

/// Özet ekranındaki kart: bugünün dengesi + haftalık ortalama.
struct EnergyBalanceCard: View {
    @Environment(AppModel.self) private var model
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text("Enerji dengesi")
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color.chevron)
                }
                .padding(.bottom, 10)

                if let energy = model.displayedEnergy {
                    balanceBody(energy)
                } else {
                    Text("Profilini tamamlayınca hesaplanır")
                        .font(.h(11.5, .bold))
                        .foregroundStyle(Color.sub)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .card(18)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) { EnergyBalanceSheet() }
    }

    @ViewBuilder
    private func balanceBody(_ energy: EnergyBalance) -> some View {
        let deficit = energy.balanceKcal < 0
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(EnergyFormat.signed(energy.balanceKcal))
                .font(.h(26))
                .foregroundStyle(deficit ? Color.greenDark : Color.warnOrange)
                .kerning(-0.6)
            Text("kcal")
                .font(.h(12, .bold))
                .foregroundStyle(Color.sub)
            Spacer()
            Text(deficit ? "açık" : "fazla")
                .font(.h(10.5, .bold))
                .foregroundStyle(deficit ? Color.greenDark : Color.warnOrange)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(deficit ? Color.greenBg : Color.warnOrangeBg))
        }
        .padding(.bottom, 8)

        HStack(spacing: 0) {
            miniCell("Aldığın", energy.intakeKcal, .green)
            Rectangle().fill(Color.hairline).frame(width: 1, height: 26)
            miniCell("Harcadığın", energy.expenditureKcal, .coral)
        }

        // Öğün girilmemişse "açık" rakamı sahte olur; bunu saklamıyoruz.
        if !energy.isUsable {
            Text("Bugün öğün kaydın yok — denge yalnızca harcamayı gösteriyor.")
                .font(.h(10, .bold))
                .foregroundStyle(Color.faint)
                .padding(.top, 8)
        } else if let average = model.weeklyAverageBalance {
            Text("7 gün ortalaması: \(EnergyFormat.signed(Int(average.rounded()))) kcal/gün")
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.sub)
                .padding(.top, 8)
        }
    }

    private func miniCell(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(EnergyFormat.grouped(value))
                .font(.h(15))
                .foregroundStyle(color)
            Text(label)
                .font(.h(10, .bold))
                .foregroundStyle(Color.sub)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detay

struct EnergyBalanceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let energy = model.displayedEnergy {
                            breakdownCard(energy)
                            weeklyCard
                            projectionCard
                        } else {
                            infoCard("Profilini tamamla",
                                     "Boy, kilo, yaş ve cinsiyet olmadan bazal metabolizma hesaplanamıyor.")
                        }
                        methodCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Text("Enerji dengesi")
                .font(.h(15))
                .foregroundStyle(Color.ink)
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Button("Kapat") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.coral)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    // MARK: Bugünün dökümü

    private func breakdownCard(_ energy: EnergyBalance) -> some View {
        VStack(spacing: 0) {
            row("Aldığın", energy.intakeKcal, color: .greenDark, bold: true)
            divider
            row("Bazal metabolizma", -energy.basalKcal, color: .inkBody)
            row(model.energyIsMeasured ? "Aktif enerji (Apple Health)"
                                       : "Aktif enerji (tahmini)",
                -energy.activeKcal, color: .inkBody)
            row("Besinin termik etkisi", -energy.thermicKcal, color: .inkBody)
            divider
            row(energy.balanceKcal < 0 ? "Açık" : "Fazla",
                energy.balanceKcal,
                color: energy.balanceKcal < 0 ? .greenDark : .warnOrange, bold: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .card(18)
    }

    private var divider: some View {
        Rectangle().fill(Color.hairline).frame(height: 1).padding(.vertical, 4)
    }

    private func row(_ label: String, _ value: Int, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.h(bold ? 12.5 : 12, bold ? .bold : .semibold))
                .foregroundStyle(bold ? Color.inkMid : Color.sub)
            Spacer()
            Text(EnergyFormat.signed(value))
                .font(.h(bold ? 15 : 13))
                .foregroundStyle(color)
        }
        .padding(.vertical, 7)
    }

    // MARK: Hafta

    private var weeklyCard: some View {
        let days = model.recentEnergyDays
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Son 7 gün")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(days.count) günde öğün kaydı var")
                    .font(.h(10, .bold))
                    .foregroundStyle(Color.faint)
            }
            if days.isEmpty {
                Text("Öğünlerini işaretledikçe burası dolar.")
                    .font(.h(11.5, .semibold))
                    .foregroundStyle(Color.sub)
            } else {
                ForEach(days, id: \.date) { day in
                    HStack {
                        Text(AppModel.workoutDayTitle(day.date))
                            .font(.h(11.5, .bold))
                            .foregroundStyle(Color.sub)
                        Spacer()
                        Text("\(EnergyFormat.grouped(day.balance.intakeKcal)) / \(EnergyFormat.grouped(day.balance.expenditureKcal))")
                            .font(.h(11, .semibold))
                            .foregroundStyle(Color.faint)
                        Text(EnergyFormat.signed(day.balance.balanceKcal))
                            .font(.h(12.5))
                            .foregroundStyle(day.balance.balanceKcal < 0 ? Color.greenDark : Color.warnOrange)
                            .frame(minWidth: 54, alignment: .trailing)
                    }
                }
                if let average = model.weeklyAverageBalance {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                    HStack {
                        Text("Ortalama")
                            .font(.h(12, .bold))
                            .foregroundStyle(Color.inkMid)
                        Spacer()
                        Text("\(EnergyFormat.signed(Int(average.rounded()))) kcal/gün")
                            .font(.h(13))
                            .foregroundStyle(average < 0 ? Color.greenDark : Color.warnOrange)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    // MARK: Tahmin

    @ViewBuilder
    private var projectionCard: some View {
        switch model.projectionGate {
        case .ready:
            VStack(alignment: .leading, spacing: 12) {
                Text("Bu tempoyu sürdürürsen")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                ForEach(Self.horizons, id: \.days) { horizon in
                    if let range = model.projectedChangeKg(days: horizon.days) {
                        HStack {
                            Text(horizon.label)
                                .font(.h(12, .bold))
                                .foregroundStyle(Color.sub)
                            Spacer()
                            Text("\(EnergyFormat.kg(range.low))–\(EnergyFormat.kg(range.high)) kg")
                                .font(.h(15))
                                .foregroundStyle(Color.greenDark)
                        }
                    }
                }
                if model.losingTooFast {
                    noteBanner("Bu hız haftada vücut ağırlığının %1'ini aşıyor. Daha yavaş bir açık hem kas kaybını hem metabolik yavaşlamayı azaltır.",
                               color: .warnOrange, bg: .warnOrangeBg)
                }
                Text("Aralık, ölçüm belirsizliğini yansıtıyor. Gerçek geri bildirim tartıdır — ölçümlerini eklemeye devam et.")
                    .font(.h(10, .bold))
                    .foregroundStyle(Color.faint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(18)

        case .gaining:
            infoCard("Şu an fazla veriyorsun",
                     "Son günlerin ortalaması artı yönde. Kilo verme tahmini yalnızca sürdürülen bir açıkta anlamlı.")

        default:
            if let message = model.projectionGate.message {
                infoCard("Tahmin henüz gösterilemiyor", message)
            }
        }
    }

    private static let horizons: [(label: String, days: Double)] = [
        ("1 ay", 30), ("3 ay", 90), ("6 ay", 180)
    ]

    // MARK: Yöntem

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nasıl hesaplanıyor?")
                .font(.h(13))
                .foregroundStyle(Color.ink)
            bullet("Bazal metabolizma **Mifflin-St Jeor** formülüyle hesaplanıyor.")
            bullet(model.energyIsMeasured
                   ? "Aktif enerji **Apple Health'ten ölçülüyor**; hareket düzeyi çarpanı kullanılmıyor, yoksa egzersiz iki kez sayılırdı."
                   : "Apple Health bağlı olmadığı için aktif enerji hareket düzeyinden **tahmin ediliyor**. Bağlarsan doğruluk artar.")
            bullet("Kilo tahmini **Hall dinamik enerji dengesi modeline** dayanıyor (*The Lancet*, 2011) — NIH Body Weight Planner'ın da kullandığı model.")
            bullet("Yaygın \"7700 kcal = 1 kg\" kuralı **kullanılmıyor**: harcamanın sabit kaldığını varsaydığı için kaybı iki katına kadar fazla tahmin eder.")
            bullet("Tek günün dengesi ölçüm hatasının içinde kalır; tahminler **7 günlük ortalamadan** üretiliyor.")
            Text("Bu bir tahmindir, tıbbi tavsiye değildir.")
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private func bullet(_ markdown: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle().fill(Color.chevron).frame(width: 4, height: 4).padding(.top, 6)
            Text(.init(markdown))
                .font(.h(11.5, .semibold))
                .foregroundStyle(Color.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func infoCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.h(13))
                .foregroundStyle(Color.ink)
            Text(body)
                .font(.h(11.5, .semibold))
                .foregroundStyle(Color.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private func noteBanner(_ text: String, color: Color, bg: Color) -> some View {
        Text(text)
            .font(.h(11, .bold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Biçimleme

enum EnergyFormat {
    static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// İşaret her zaman görünür: "−470", "+180".
    static func signed(_ value: Int) -> String {
        value < 0 ? "−" + grouped(-value) : "+" + grouped(value)
    }

    /// "2,7" — Türkçe ondalık ayırıcı, tek basamak.
    static func kg(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

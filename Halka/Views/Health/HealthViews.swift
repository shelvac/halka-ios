import SwiftUI
import UniformTypeIdentifiers

/// Sağlık tab: Vücut / Değerlerim / Takviyeler panes + profile.
struct HealthView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if model.healthPane == .profile {
                    ProfileView()
                } else {
                    header
                    paneChips
                        .padding(.bottom, 16)
                    switch model.healthPane {
                    case .body: BodyPane()
                    case .blood: BloodPane()
                    case .supplements: SupplementsPane()
                    case .profile: EmptyView()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }

    private var header: some View {
        HStack {
            Text("Sağlık")
                .font(.h(24))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
            Spacer()
            Button { model.healthPane = .profile } label: {
                MeAvatar(size: 38)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var paneChips: some View {
        HStack(spacing: 6) {
            paneChip("Vücut", pane: .body)
            paneChip("Değerlerim", pane: .blood)
            paneChip("Takviyeler", pane: .supplements)
        }
    }

    private func paneChip(_ title: String, pane: HealthPane) -> some View {
        let active = model.healthPane == pane
        return Button { model.healthPane = pane } label: {
            Text(title)
                .font(.h(12))
                .foregroundStyle(active ? .white : Color.sub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(active ? Color.coral : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: active ? Color.coral.opacity(0.3) : Color.ink.opacity(0.05),
                        radius: active ? 5 : 3, y: active ? 3 : 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vücut

struct BodyPane: View {
    @Environment(AppModel.self) private var model
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 0) {
            // PDF upload
            HStack {
                Spacer()
                Button { showImporter = true } label: {
                    Text("PDF Yükle")
                        .font(.h(12))
                        .foregroundStyle(Color.coralDark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.coralBg))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result {
                    model.processBodyPdf(named: url.lastPathComponent)
                }
            }

            if model.bodyPdfState == .processing {
                processingBanner("\(model.bodyPdfName) ayrıştırılıyor — OCR metrikleri okuyor…")
                    .padding(.bottom, 10)
            }
            if model.bodyPdfState == .done {
                doneBanner("\(model.bodyPdfName) işlendi — 17 metrik geçmişe kaydedildi")
                    .padding(.bottom, 10)
            }

            weightCard
            metricsCard
                .padding(.top, 12)
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Son tartım · 05.08.2026, 09:03")
                .font(.h(12, .bold))
                .foregroundStyle(Color.sub)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("72.15")
                    .font(.h(42))
                    .foregroundStyle(Color.ink)
                    .kerning(-1.5)
                Text("kg").font(.h(15, .bold)).foregroundStyle(Color.sub)
                Spacer()
                Text("+2.15 kg · 16 Tem'den beri")
                    .font(.h(11))
                    .foregroundStyle(Color.goldDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.goldBg))
            }
            .padding(.top, 4)
            .padding(.bottom, 12)

            // BMI band with marker (BMI 26.2 → 44.8% across the band, from the prototype)
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        HStack(spacing: 3) {
                            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4, bottomLeading: 4))
                                .fill(Color.bmiLow)
                            Rectangle().fill(Color.bmiOk)
                            Rectangle().fill(Color.bmiHigh)
                            UnevenRoundedRectangle(cornerRadii: .init(bottomTrailing: 4, topTrailing: 4))
                                .fill(Color.bmiObese)
                        }
                        .frame(height: 8)
                        .padding(.top, 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.ink)
                            .frame(width: 4, height: 16)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white, lineWidth: 2))
                            .offset(x: geo.size.width * 0.448 - 2)
                    }
                }
                .frame(height: 16)
                HStack {
                    Text("Düşük"); Spacer(); Text("Sağlıklı"); Spacer(); Text("Yüksek"); Spacer(); Text("Obez")
                }
                .font(.h(9.5, .bold))
                .foregroundStyle(Color.faint)
            }

            HStack {
                statColumn("BMI", "26.2")
                Spacer()
                statColumn("30 günlük en iyi", "70.00 kg")
                Spacer()
                statColumn("Metabolik yaş", "41")
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline2).frame(height: 1)
            }
            .padding(.top, 14)
        }
        .padding(20)
        .card(22)
    }

    private func statColumn(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.h(10, .bold)).foregroundStyle(Color.faint)
            Text(value).font(.h(15)).foregroundStyle(Color.ink)
        }
    }

    private var metricsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(Demo.bodyMetrics.enumerated()), id: \.element.id) { i, metric in
                let colors = statusColors(metric.status)
                HStack(spacing: 10) {
                    Text(metric.name)
                        .font(.h(13, .bold))
                        .foregroundStyle(Color.inkBody)
                    Spacer()
                    (Text(metric.value).font(.h(15)).foregroundColor(.ink)
                     + Text(" \(metric.unit)").font(.h(10, .bold)).foregroundColor(.faint))
                    StatusChip(text: metric.status, bg: colors.bg, fg: colors.fg, minWidth: 62)
                }
                .padding(.vertical, 13)
                .overlay(alignment: .top) {
                    if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .card(22)
    }
}

// MARK: - Değerlerim (blood tests)

struct BloodPane: View {
    @Environment(AppModel.self) private var model
    @State private var showImporter = false

    var body: some View {
        let counts = model.bloodCounts
        VStack(spacing: 0) {
            // Header card
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kan Tahlili").font(.h(15)).foregroundStyle(Color.ink)
                        Text("29.11.2025 · Medicana Ataşehir")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Button { showImporter = true } label: {
                        Text("PDF Yükle")
                            .font(.h(12))
                            .foregroundStyle(Color.coralDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.coralBg))
                    }
                    .buttonStyle(.plain)
                }
                .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf]) { result in
                    if case .success(let url) = result {
                        model.processBloodPdf(named: url.lastPathComponent)
                    }
                }

                if model.bloodPdfState == .processing {
                    HStack(spacing: 11) {
                        SpinnerArc(size: 20)
                        Text("\(model.bloodPdfName) ayrıştırılıyor — test değerleri okunuyor…")
                            .font(.h(12.5))
                            .foregroundStyle(Color.ink)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                    .padding(.top, 12)
                }
                if model.bloodPdfState == .done {
                    HStack(spacing: 11) {
                        CheckBadge(size: 20)
                        Text("\(model.bloodPdfName) işlendi — 16 test değeri eklendi")
                            .font(.h(12.5))
                            .foregroundStyle(Color.greenDark)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                    .padding(.top, 12)
                }

                HStack(spacing: 14) {
                    countColumn("Toplam test", "\(counts.total)", .ink)
                    countColumn("Normal", "\(counts.ok)", .greenDark)
                    countColumn("Takip gerekli", "\(counts.warn)", .goldDark)
                    Spacer()
                }
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(Color.hairline).frame(height: 1) }
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .card(22)

            // Test groups
            ForEach(Demo.bloodGroups) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.name)
                        .font(.h(12))
                        .foregroundStyle(Color.brown)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    ForEach(Array(group.tests.enumerated()), id: \.element.id) { i, test in
                        testRow(test, topBorder: i > 0)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(20)
                .padding(.top, 12)
            }

            Text("AI Koç notu: MPV hafif yüksek, D vitamini ve B12 bu panelde yok — bir sonraki tahlilde ekletmeni öneririm. Protein alımın düşüktü; ferritin takibi de faydalı olur.")
                .font(.h(11.5, .semibold))
                .foregroundStyle(Color.coralNote)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.coralBg)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 12)
        }
    }

    private func countColumn(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.h(10, .bold)).foregroundStyle(Color.faint)
            Text(value).font(.h(15)).foregroundStyle(color)
        }
    }

    private func testRow(_ test: BloodTest, topBorder: Bool) -> some View {
        let colors = statusColors(test.status)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(test.name)
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.inkBody)
                Text("Referans: \(refText(test))")
                    .font(.h(10, .bold))
                    .foregroundStyle(Color.faint)
                // Reference band with position dot
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline2).frame(height: 5)
                        Circle()
                            .fill(test.status == "Normal" ? Color.green : Color(hex: 0xD9962E))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .offset(x: geo.size.width * test.refPosition - 5)
                    }
                }
                .frame(maxWidth: 150)
                .frame(height: 10)
                .padding(.top, 3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                (Text(test.display).font(.h(15)).foregroundColor(.ink)
                 + Text(" \(test.unit)").font(.h(10, .bold)).foregroundColor(.faint))
                StatusChip(text: test.status, bg: colors.bg, fg: colors.fg)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            if topBorder { Rectangle().fill(Color.hairline).frame(height: 1) }
        }
    }

    private func refText(_ test: BloodTest) -> String {
        func fmt(_ v: Double) -> String {
            v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
        }
        return "\(fmt(test.refLow)) – \(fmt(test.refHigh)) \(test.unit)"
    }
}

// MARK: - Takviyeler

struct SupplementsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            // Dark summary card
            HStack(spacing: 12) {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.supplementSummary)
                        .font(.h(13))
                        .foregroundStyle(.white)
                    Text("Zili açık olanlara saatinde bildirim gider")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ink)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            ForEach(model.supplements) { supp in
                HStack(spacing: 12) {
                    Button { model.toggleSupplementTaken(supp.id) } label: {
                        RoundCheck(on: supp.taken, size: 24)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supp.name)
                            .font(.h(13.5))
                            .foregroundStyle(supp.taken ? Color.faint : Color.ink)
                            .strikethrough(supp.taken)
                        Text(supp.dose)
                            .font(.h(10.5, .bold))
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                    Text(supp.time)
                        .font(.h(11))
                        .monospacedDigit()
                        .foregroundStyle(Color.inkMid)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.bgField))
                    Button { model.toggleSupplementNotify(supp.id) } label: {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(supp.notify ? Color.coralBg : Color.bgField)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: supp.notify ? "bell.fill" : "bell")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(supp.notify ? Color.coral : Color.faint)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                .padding(.top, 10)
            }

            DashedAction(title: "+ Takviye / ilaç ekle")
                .padding(.top, 10)
        }
    }
}

// MARK: - Shared banners

func processingBanner(_ text: String) -> some View {
    HStack(spacing: 11) {
        SpinnerArc(size: 20)
        Text(text).font(.h(12.5)).foregroundStyle(Color.ink)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: Color.ink.opacity(0.06), radius: 4, y: 2)
}

func doneBanner(_ text: String) -> some View {
    HStack(spacing: 11) {
        CheckBadge(size: 20)
        Text(text).font(.h(12.5)).foregroundStyle(Color.greenDark)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .background(Color.greenBg)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
}

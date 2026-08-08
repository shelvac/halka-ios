import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                segmentControl
                    .padding(.bottom, 16)

                switch model.homeSegment {
                case .today: TodayView()
                case .calendar: CalendarPane()
                case .social: SocialPane()
                case .dietitian: DietitianMarketPane()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.todayHeaderTitle)
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.sub)
                Text("Merhaba, \(model.userName)")
                    .font(.h(26))
                    .foregroundStyle(Color.ink)
                    .kerning(-0.5)
            }
            Spacer()
            Button {
                model.tab = .health
                model.healthPane = .profile
            } label: {
                ProfileAvatar(image: model.avatarImage,
                              fullName: model.userFullName, size: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    private var segmentControl: some View {
        HStack(spacing: 4) {
            ForEach(HomeSegment.allCases, id: \.self) { seg in
                let active = model.homeSegment == seg
                Button { model.homeSegment = seg } label: {
                    Text(seg.title)
                        .font(.h(12.5))
                        .foregroundStyle(active ? Color.ink : Color.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Color.white : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .shadow(color: active ? Color.ink.opacity(0.09) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .minimumScaleFactor(0.8)
            }
        }
        .padding(4)
        .background(Color.bgSand)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Today

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var editingSleep = false

    var body: some View {
        VStack(spacing: 0) {
            ringsCard
            activityStats
                .padding(.top, 12)
            quickActions
                .padding(.top, 12)
            goalGrid
                .padding(.top, 14)
            weekStrip
                .padding(.top, 14)
            streakCard
                .padding(.top, 14)
        }
        .sheet(isPresented: $editingSleep) {
            MeasurePickerSheet(
                title: "Uyku",
                unit: "sa",
                range: 0...14,
                allowsDecimal: true,
                value: Binding(
                    get: { model.sleepHours > 0 ? model.sleepHours : nil },
                    set: { model.setSleepHours($0 ?? 0) }))
        }
    }

    private var ringsCard: some View {
        HStack(spacing: 16) {
            RingStack(fractions: model.todayFractions, size: 176)
            VStack(alignment: .leading, spacing: 13) {
                ForEach(RingKind.allCases, id: \.self) { kind in
                    legendRow(kind)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .card(22)
    }

    /// Adım ve aktif enerji — halka DEĞİL, istatistik.
    ///
    /// Adımı egzersiz halkasına katmıyoruz: Apple tempolu yürüyüşü zaten
    /// egzersiz dakikası olarak sayıyor, ikisini toplamak aynı hareketi iki kez
    /// saymak olurdu. Burada hedefsiz, dürüst bir gösterim var.
    @ViewBuilder
    private var activityStats: some View {
        if model.hkConnected {
            HStack(spacing: 0) {
                // Uyku artık halka değil: hedefe koşulacak bir şey değil,
                // olan bir şey. Ölçülüyor ama baskı yapmadan gösteriliyor.
                // Saati geceleri takmayan kullanıcı uykusunu elle girebilsin;
                // Health'ten veri geldiğinde o öncelikli olur.
                Button { editingSleep = true } label: {
                    statCell(icon: "moon.zzz.fill",
                             value: model.sleepHours > 0
                                 ? String(format: "%.1f", model.sleepHours) : "—",
                             label: model.sleepHours > 0 ? "saat uyku" : "uyku ekle",
                             color: .sleepPurple)
                }
                .buttonStyle(.plain)
                Rectangle().fill(Color.hairline).frame(width: 1, height: 34)
                statCell(icon: "flame.fill",
                         value: Self.grouped(model.hkActiveEnergy),
                         label: "kcal aktif",
                         color: .warnOrange)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .card(18)

            // Apple Watch'ta yapılan antrenmanlar — egzersiz halkasının
            // "neden dolu" sorusunun cevabı.
            if !model.todayWorkouts.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(model.todayWorkouts.enumerated()), id: \.element.id) { i, workout in
                        HStack(spacing: 10) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color.coral)
                            Text(workout.name)
                                .font(.h(12.5, .bold))
                                .foregroundStyle(Color.inkBody)
                            Spacer()
                            Text("\(workout.minutes) dk")
                                .font(.h(12.5))
                                .foregroundStyle(Color.ink)
                            if workout.kcal > 0 {
                                Text("· \(workout.kcal) kcal")
                                    .font(.h(11, .bold))
                                    .foregroundStyle(Color.sub)
                            }
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .card(18)
                .padding(.top, 10)
            }
        } else {
            // Bağlı değilken sahte sayı göstermek yerine bağlanmaya çağır.
            Button {
                model.tab = .health
                model.healthPane = .profile
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.coral)
                    Text("Adım, uyku ve enerji için Apple Health'i bağla")
                        .font(.h(12, .bold))
                        .foregroundStyle(Color.inkBody)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.chevron)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .card(18)
            }
            .buttonStyle(.plain)
        }
    }

    private func statCell(icon: String, value: String, label: String,
                          color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.h(18))
                    .foregroundStyle(Color.ink)
            }
            Text(label)
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.sub)
        }
        .frame(maxWidth: .infinity)
    }

    /// 8432 → "8.432" (Türkçe binlik ayırıcı).
    private static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func legendRow(_ kind: RingKind) -> some View {
        let color: Color = switch kind {
        case .exercise: .coral
        case .water: .waterBlue
        case .steps: .stepPurple
        case .nutrition: .green
        }
        let cur = model.currentValue(kind)
        let goalValue = model.goal(for: kind)
        let curText = Self.grouped(Int(cur))
        let goalText = Self.grouped(Int(goalValue))
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(kind.name)
                    .font(.h(11, .bold))
                    .foregroundStyle(Color.sub)
            }
            (Text("\(curText) / \(goalText)")
                .font(.h(16))
                .foregroundColor(color)
             + Text(" \(kind.unit)")
                .font(.h(10, .bold))
                .foregroundColor(.faint))
                .kerning(-0.3)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            // Su sayacı: eksi/artı birlikte. Eskiden yalnızca eklemenin
            // ardından 6 saniye görünen tek seferlik "Geri al" vardı; sonradan
            // düzeltmenin yolu yoktu.
            HStack(spacing: 0) {
                Button { model.removeWater() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(model.water > 0 ? Color.blueDark : Color.chevron)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .disabled(model.water == 0)

                Text("\(model.water) ml")
                    .font(.h(12))
                    .foregroundStyle(Color.blueDark)
                    .frame(minWidth: 56)

                Button { model.addWater() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.blueDark)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .background(Capsule().fill(Color.blueBg))

            Button {
                model.tab = .meal
                model.mealView = .photo
            } label: {
                pillLabel("Öğün ekle")
            }
            .buttonStyle(.plain)

            Button {
                model.tab = .workout
                model.workoutView = .home
            } label: {
                pillLabel("Egzersiz")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: model.water)
    }

    private func pillLabel(_ text: String) -> some View {
        Text(text)
            .font(.h(12, .bold))
            .foregroundStyle(Color.inkMid)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.white))
            .shadow(color: Color.ink.opacity(0.05), radius: 3, y: 1)
    }

    private var goalGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            ForEach(RingKind.allCases, id: \.self) { kind in
                goalCard(kind)
            }
        }
    }

    private func goalCard(_ kind: RingKind) -> some View {
        let color: Color = switch kind {
        case .exercise: .coral
        case .water: .waterBlue
        case .steps: .stepPurple
        case .nutrition: .green
        }
        let cur = model.currentValue(kind)
        let goalValue = model.goal(for: kind)
        let pct = min(cur / goalValue, 1)
        let big = Self.grouped(Int(cur))
        let remaining = max(goalValue - cur, 0)
        let leftText = pct >= 1
            ? "Hedef tamamlandı"
            : "Kalan: \(Self.grouped(Int(remaining))) \(kind.unit)"

        return VStack(alignment: .leading, spacing: 0) {
            Text(kind.name)
                .font(.h(11, .bold))
                .foregroundStyle(Color.sub)
            Text("\(big) \(kind.unit)")
                .font(.h(19))
                .foregroundStyle(Color.ink)
                .kerning(-0.4)
                .padding(.top, 2)
                .padding(.bottom, 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.hairline2)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.4), value: pct)
            Text(leftText)
                .font(.h(10, .bold))
                .foregroundStyle(Color.faint)
                .padding(.top, 6)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bu hafta")
                .font(.h(13))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 4)
            HStack {
                // US-024: hafta gerçek takvimden — eskiden 3-9 Ağustos'a sabitti.
                ForEach(Array(model.currentWeek.enumerated()), id: \.offset) { i, date in
                    let isToday = AppModel.appCalendar.isDate(date, inSameDayAs: model.today)
                    VStack(spacing: 5) {
                        MiniRings(fractions: model.fractions(for: date))
                        Text(Demo.dayNamesShort[i])
                            .font(.h(10))
                            .foregroundStyle(isToday ? Color.ink : Color.faint)
                    }
                    if i < 6 { Spacer() }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .card(20)
    }

    private var streakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.8)
                    .stroke(Color.coral, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 27, height: 27)
                Circle().fill(Color.coral).frame(width: 11, height: 11)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("12 günlük seri")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                Text("Her gün %1 daha iyi — halkaları kapatmaya devam.")
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.coralNote)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.coralBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

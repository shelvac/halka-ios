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
                Text("5 Ağustos, Çarşamba")
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
                MeAvatar(size: 44)
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

    var body: some View {
        VStack(spacing: 0) {
            ringsCard
            quickActions
                .padding(.top, 12)
            goalGrid
                .padding(.top, 14)
            weekStrip
                .padding(.top, 14)
            streakCard
                .padding(.top, 14)
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

    private func legendRow(_ kind: RingKind) -> some View {
        let color: Color = switch kind {
        case .exercise: .coral
        case .water: .waterBlue
        case .sleep: .sleepPurple
        case .nutrition: .green
        }
        let cur = model.currentValue(kind)
        let curText = kind == .sleep ? String(format: "%.1f", cur) : "\(Int(cur))"
        let goalValue = model.goal(for: kind)
        let goalText = kind == .sleep ? String(format: "%.0f", goalValue) : "\(Int(goalValue))"
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
            Button { model.addWater() } label: {
                Text("+ 250 ml su")
                    .font(.h(12))
                    .foregroundStyle(Color.blueDark)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.blueBg))
            }
            .buttonStyle(.plain)

            if model.waterUndoVisible {
                Button { model.undoWater() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .heavy))
                        Text("Geri al").font(.h(12))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.ink))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

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
        .animation(.easeInOut(duration: 0.2), value: model.waterUndoVisible)
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
        case .sleep: .sleepPurple
        case .nutrition: .green
        }
        let cur = model.currentValue(kind)
        let goalValue = model.goal(for: kind)
        let pct = min(cur / goalValue, 1)
        let big = kind == .sleep ? String(format: "%.1f", cur) : "\(Int(cur))"
        let remaining = goalValue - cur
        let leftText = pct >= 1
            ? "Hedef tamamlandı"
            : "Kalan: \(kind == .sleep ? String(format: "%.1f", remaining) : "\(Int(remaining))") \(kind.unit)"

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
                ForEach(0..<7, id: \.self) { i in
                    let dayNumber = 3 + i    // week runs Aug 3 (Mon) – Aug 9
                    VStack(spacing: 5) {
                        MiniRings(fractions: dayNumber <= 5 ? model.fractions(forDay: dayNumber) : [0, 0, 0, 0])
                        Text(Demo.dayNamesShort[i])
                            .font(.h(10))
                            .foregroundStyle(dayNumber == 5 ? Color.ink : Color.faint)
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

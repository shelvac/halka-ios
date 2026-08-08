import SwiftUI

/// Yemek tab root — routes between menu, log, detail, catalog, photo, market.
struct MealsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                switch model.mealView {
                case .menu: MealMenuView()
                case .log: CalorieLogView()
                case .detail: MealDetailView()
                case .catalog: MealCatalogView()
                case .photo: PhotoLogView()
                case .market: MarketListPane()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }
}

// MARK: - Menu (day picker + plan rows + log card + actions)

struct MealMenuView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Yemek Planı")
                .font(.h(24))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
                .padding(.top, 12)
            Text(model.mealDayTitle)
                .font(.h(12, .bold))
                .foregroundStyle(Color.sub)
                .padding(.top, 2)
                .padding(.bottom, 14)

            dayChips
                .padding(.bottom, 14)
            menuCard
            logCard
                .padding(.top, 10)
            actionGrid
                .padding(.top, 14)
            marketRow
                .padding(.top, 10)
        }
    }

    private var dayChips: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let active = model.mealDay == i
                Button {
                    model.mealDay = i
                    model.mealView = .menu
                } label: {
                    Text(Demo.dayNamesShort[i])
                        .font(.h(11.5))
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
    }

    private var menuCard: some View {
        let day = model.mealDay
        let extras = model.extras(forDay: day)
        return VStack(spacing: 0) {
            ForEach(Array(model.visibleMenu(forDay: day).enumerated()), id: \.element.slot) { row, item in
                let i = item.slot
                let food = item.food
                let eaten = model.isEaten(day: day, slot: i)
                let recipe = model.recipe(for: food, slot: i)
                Button {
                    model.openMealDetail(food: food, slot: i, from: .menu)
                } label: {
                    HStack(spacing: 10) {
                        Button { model.toggleEaten(day: day, slot: i) } label: {
                            RoundCheck(on: eaten)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(model.mealTimes[i])
                                .font(.h(12))
                                .foregroundStyle(Color.coral)
                            Text(Demo.mealLabels[i])
                                .font(.h(9.5))
                                .foregroundStyle(Color.faint)
                        }
                        .frame(width: 44, alignment: .leading)
                        Text(food)
                            .font(.h(13, .bold))
                            .foregroundStyle(eaten ? Color.faint : Color.inkSoft)
                            .strikethrough(eaten)
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Text("\(recipe.kcal) kcal")
                            .font(.h(11))
                            .foregroundStyle(Color.sub)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color.chevron)
                    }
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                // Beğenilmeyen öğünü kaldırmanın tek yolu katalogdan
                // başkasıyla değiştirmekti; artık kaldırılabiliyor.
                .contextMenu {
                    Button(role: .destructive) {
                        model.removeMeal(day: day, slot: i)
                    } label: {
                        Label("Menüden kaldır", systemImage: "trash")
                    }
                }
                .overlay(alignment: .top) {
                    if row > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                }
            }

            ForEach(extras) { extra in
                // Plan satırıyla AYNI düzen: onay dairesi · saat + etiket ·
                // ad · kalori. Eskiden farklı bir biçimdeydi (nokta, tek
                // satırda "saat · ad") ve aynı listede iki dil konuşuyordu.
                HStack(spacing: 10) {
                    RoundCheck(on: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(extra.time)
                            .font(.h(12))
                            .foregroundStyle(Color.coral)
                        Text("Ekstra")
                            .font(.h(9.5))
                            .foregroundStyle(Color.faint)
                    }
                    .frame(width: 44, alignment: .leading)
                    Text(extra.title)
                        .font(.h(13, .bold))
                        .foregroundStyle(Color.inkSoft)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Text("\(extra.kcal) kcal")
                        .font(.h(11))
                        .foregroundStyle(Color.sub)
                    Button { model.deleteExtra(extra.id) } label: {
                        Circle()
                            .fill(Color.bgChip)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(Color.sub)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 13)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 1)
                        .overlay(
                            Line().stroke(Color(hex: 0xEAE3D6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                }
            }

            if model.removedCount(forDay: day) > 0 {
                HStack {
                    Text("\(model.removedCount(forDay: day)) öğün kaldırıldı")
                        .font(.h(11, .bold))
                        .foregroundStyle(Color.faint)
                    Spacer()
                    Button { model.restoreMeals(day: day) } label: {
                        Text("Geri al")
                            .font(.h(11, .bold))
                            .foregroundStyle(Color.coral)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
            }

            HStack {
                Text("Günün toplamı").font(.h(12)).foregroundStyle(Color.ink)
                Spacer()
                Text("~\(model.planTotal(forDay: day)) kcal · Hedef 1420")
                    .font(.h(12))
                    .foregroundStyle(Color.green)
            }
            .padding(.vertical, 13)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .card(22)
    }

    private var logCard: some View {
        let consumed = model.consumed(forDay: model.mealDay)
        let pct = min(Double(consumed) / 1420, 1)
        return Button { model.mealView = .log } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kalori Günlüğüm")
                        .font(.h(13))
                        .foregroundStyle(.white)
                    Text("Yediklerinin kaydı — halkalar buradan hesaplanır")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(Color.greenSoft)
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 5)
                    .padding(.top, 8)
                }
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(consumed)")
                        .font(.h(19))
                        .foregroundStyle(Color.greenSoft)
                        .kerning(-0.4)
                    Text("/ 1420 kcal")
                        .font(.h(9.5, .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.ink)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actionGrid: some View {
        HStack(spacing: 10) {
            Button { model.mealView = .photo } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Başka bir şey yedim")
                        .font(.h(13))
                        .foregroundStyle(.white)
                    Text("Fotoğraf at, AI kaloriyi hesaplasın")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.coral)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.coral.opacity(0.28), radius: 7, y: 4)
            }
            .buttonStyle(.plain)

            Button { model.mealView = .catalog } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Başka bir şey yemek istiyorum")
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Text("Katalogdan alternatif seç")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(Color.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var marketRow: some View {
        Button { model.mealView = .market } label: {
            HStack(spacing: 10) {
                Image(systemName: "cart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Günün market listesi")
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Text("Menüdeki malzemeler tek listede")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color.chevron)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// Simple horizontal line shape (dashed separators).
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Calorie log

struct CalorieLogView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let day = model.mealDay
        let consumed = model.consumed(forDay: day)
        let over = consumed > 1420
        let pct = min(Double(consumed) / 1420, 1)
        let planRows = model.visibleMenu(forDay: day)
            .filter { model.isEaten(day: day, slot: $0.slot) }
        let extras = model.extras(forDay: day)

        return VStack(alignment: .leading, spacing: 0) {
            BackRow(label: "Menüye dön") { model.mealView = .menu }

            Text("Kalori Günlüğüm")
                .font(.h(22))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
            Text("\(model.mealDayTitle) — yenen her şey burada kayıtlı")
                .font(.h(12, .semibold))
                .foregroundStyle(Color.sub)
                .padding(.top, 2)
                .padding(.bottom, 14)

            // Summary card
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(consumed)")
                        .font(.h(36))
                        .foregroundStyle(Color.ink)
                        .kerning(-1)
                    Text("/ 1420 kcal")
                        .font(.h(13, .bold))
                        .foregroundStyle(Color.sub)
                    Spacer()
                    Text(over ? "+\(consumed - 1420) kcal aşım" : "\(1420 - consumed) kcal kaldı")
                        .font(.h(10.5))
                        .foregroundStyle(over ? Color.coralDark : Color.greenDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(over ? Color.coralBg : Color.greenBg))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline2)
                        Capsule()
                            .fill(over ? Color.coral : Color.green)
                            .frame(width: geo.size.width * pct)
                    }
                }
                .frame(height: 8)
                .padding(.top, 12)
                Text("Beslenme halkası bu günlükten hesaplanır · Hedef: BMR 1420 kcal")
                    .font(.h(10.5, .bold))
                    .foregroundStyle(Color.faint)
                    .padding(.top, 8)
            }
            .padding(20)
            .card(22)

            // Entries
            VStack(spacing: 0) {
                if planRows.isEmpty && extras.isEmpty {
                    Text("Bugün henüz kayıt yok — menüdeki öğünü yedikçe işaretle veya fotoğraf at.")
                        .font(.h(12, .semibold))
                        .foregroundStyle(Color.faint)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(planRows.enumerated()), id: \.element.slot) { idx, pair in
                        logRow(
                            time: model.mealTimes[pair.slot],
                            food: pair.food,
                            kcal: "\(model.recipe(for: pair.food, slot: pair.slot).kcal) kcal",
                            source: "Plandan · \(Demo.mealLabels[pair.slot])",
                            sourceColors: (Color.blueBg, Color.blueDark),
                            deletable: nil,
                            topBorder: idx > 0)
                    }
                    ForEach(Array(extras.enumerated()), id: \.element.id) { idx, extra in
                        logRow(
                            time: extra.time,
                            food: extra.title,
                            kcal: "\(extra.kcal) kcal",
                            source: "Fotoğraftan",
                            sourceColors: (Color.coralBg, Color.coralDark),
                            deletable: { model.deleteExtra(extra.id) },
                            topBorder: idx > 0 || !planRows.isEmpty)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .card(20)
            .padding(.top, 12)
        }
    }

    private func logRow(time: String, food: String, kcal: String,
                        source: String, sourceColors: (Color, Color),
                        deletable: (() -> Void)?, topBorder: Bool) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.h(11.5))
                .foregroundStyle(Color.faint)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(food)
                    .font(.h(13, .bold))
                    .foregroundStyle(Color.inkSoft)
                    .lineSpacing(2)
                Text(source)
                    .font(.h(9.5))
                    .foregroundStyle(sourceColors.1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(sourceColors.0))
            }
            Spacer()
            Text(kcal).font(.h(12)).foregroundStyle(Color.ink)
            if let deleteAction = deletable {
                Button(action: deleteAction) {
                    Circle()
                        .fill(Color.bgChip)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Color.sub)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            if topBorder { Rectangle().fill(Color.hairline).frame(height: 1) }
        }
    }
}

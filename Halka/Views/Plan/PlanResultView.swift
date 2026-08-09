import SwiftUI

/// Üretilen haftalık menü ve antrenman programı (US-032 · US-033).
struct PlanResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Pane = .meals
    @State private var selectedDay = 0
    @State private var editingPlan = false

    enum Pane: String, CaseIterable { case meals, workouts
        var title: String { self == .meals ? "Beslenme" : "Antrenman" }
    }

    /// Yalnızca istenen bölümler: "sadece beslenme" kuruluysa boş bir
    /// Antrenman sekmesi hiç görünmemeli (tersi de öyle).
    private var panes: [Pane] {
        var list = [Pane]()
        if model.planParts.contains(.meals) { list.append(.meals) }
        if model.planParts.contains(.workouts) { list.append(.workouts) }
        return list.isEmpty ? [.meals] : list
    }

    var body: some View {
        ZStack {
            Color.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                // Günler geldikçe ekran doluyor; tam ekran bekleme yalnızca
                // besin planı istenmişken henüz HİÇ gün yokken.
                if model.planBusy && model.planParts.contains(.meals)
                    && (model.mealPlan?.days.isEmpty ?? true) {
                    Spacer()
                    SpinnerArc(size: 26)
                    Text("Planın hazırlanıyor · \(model.planProgress)/7 gün")
                        .font(.h(12, .bold))
                        .foregroundStyle(Color.sub)
                        .padding(.top, 10)
                    Text("İlk günler ~yarım dakikada gelir")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.faint)
                        .padding(.top, 2)
                    Spacer()
                } else {
                    if panes.count > 1 { segment }
                    dayStrip
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            switch tab {
                            case .meals: mealContent
                            case .workouts: workoutContent
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .onAppear { if !panes.contains(tab) { tab = panes[0] } }
        .onChange(of: model.planParts) { if !panes.contains(tab) { tab = panes[0] } }
    }

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: 1) {
                Text("Haftalık planım")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                if let plan = model.mealPlan {
                    Text("Hedef \(plan.kcalTarget) kcal · ortalama \(plan.averageKcal) kcal")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.sub)
                }
            }
            Spacer()
        }
        .overlay(alignment: .leading) {
            // Plan tek seferlik bir karar değil: tercihler değişir, hedef
            // değişir, sıkılırsın. Her zaman yeniden kurulabilmeli.
            Button("Yeniden kur") { editingPlan = true }
                .font(.h(13))
                .foregroundStyle(Color.sub)
        }
        .overlay(alignment: .trailing) {
            Button("Kapat") { dismiss() }
                .font(.h(13))
                .foregroundStyle(Color.coral)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .sheet(isPresented: $editingPlan) {
            PlanWizardView(presentsResult: false)
        }
    }

    private var segment: some View {
        HStack(spacing: 4) {
            ForEach(panes, id: \.self) { pane in
                let active = tab == pane
                Button { tab = pane } label: {
                    Text(pane.title)
                        .font(.h(12.5))
                        .foregroundStyle(active ? Color.ink : Color.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Color.white : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .shadow(color: active ? Color.ink.opacity(0.09) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.bgSand)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 18)
    }

    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                let active = selectedDay == day
                // Antrenman anında üretilir; besin günleri geldikçe açılır.
                let ready = tab == .workouts
                    ? model.workoutPlan != nil
                    : model.mealPlan?.days.contains { $0.day == day } ?? false
                Button { selectedDay = day } label: {
                    Text(Demo.dayNamesShort[day])
                        .font(.h(11.5, .bold))
                        .foregroundStyle(active ? .white : (ready ? Color.sub : Color.chevron))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(active ? Color.coral : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    // MARK: Beslenme

    @ViewBuilder
    private var mealContent: some View {
        // Dizi indeksi DEĞİL gün numarasıyla ara: paralel üretimde günler
        // sırayla gelmiyor, indeksle bakmak yanlış günü gösterirdi.
        if let plan = model.mealPlan,
           let day = plan.days.first(where: { $0.day == selectedDay }) {
            macroCard(plan, dayKcal: day.kcal)
            ForEach(day.meals) { meal in
                mealCard(meal)
            }
            // Planın nereden geldiğini saklamıyoruz.
            if let source = model.planSource {
                noteBox(source == "ai"
                    ? "Menü, diyetisyen kurallarıyla eğitilmiş yapay zekâ tarafından kuruldu ve her gün uygulamanın kendi kural denetiminden (tek ana yemek, protein karışımı yok, kahvaltı bütünlüğü, ±%5 kalori, alerjen taraması) geçti."
                    : source == "mixed"
                    ? "Bazı günler yapay zekâ ile kuruldu, denetimden geçemeyen günler kural tabanlı üreticiden geldi."
                    : "Yapay zekâya ulaşılamadığı için menü kural tabanlı üreticiyle kuruldu.")
            }
            // Havuz daralırsa menü tekrara düşer; bunu saklamıyoruz.
            if plan.poolSize < 40 {
                noteBox("Tercihlerin havuzu \(plan.poolSize) yemeğe indirdi. Çeşitliliği artırmak için bazı kısıtları gevşetmen gerekebilir.")
            }
        } else if model.planBusy {
            VStack(spacing: 8) {
                SpinnerArc(size: 22)
                Text("Bu gün hazırlanıyor…")
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.sub)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .card(18)
        } else {
            noteBox("Bu gün üretilemedi. Koça \"\(AppModel.chipRegenMeals)\" yazarsan yeniden denerim.")
        }
    }

    private func macroCard(_ plan: WeekMealPlan, dayKcal: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(dayKcal)")
                    .font(.h(26))
                    .foregroundStyle(Color.coral)
                    .kerning(-0.6)
                Text("/ \(plan.kcalTarget) kcal")
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.sub)
                Spacer()
                let off = abs(dayKcal - plan.kcalTarget) * 100 / max(1, plan.kcalTarget)
                Text(off <= 5 ? "hedefte" : "%\(off) sapma")
                    .font(.h(10, .bold))
                    .foregroundStyle(off <= 5 ? Color.greenDark : Color.warnOrange)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(off <= 5 ? Color.greenBg : Color.warnOrangeBg))
            }
            HStack(spacing: 0) {
                macroCell("Protein", plan.proteinTarget, .coral)
                Rectangle().fill(Color.hairline).frame(width: 1, height: 26)
                macroCell("Karbonhidrat", plan.carbTarget, .waterBlue)
                Rectangle().fill(Color.hairline).frame(width: 1, height: 26)
                macroCell("Yağ", plan.fatTarget, .warnOrange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private func macroCell(_ label: String, _ grams: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(grams) g").font(.h(14)).foregroundStyle(color)
            Text(label).font(.h(9.5, .bold)).foregroundStyle(Color.sub)
                .minimumScaleFactor(0.8).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func mealCard(_ meal: PlannedMeal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(meal.time)
                    .font(.h(12))
                    .foregroundStyle(Color.coral)
                Text(meal.label)
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(meal.kcal) kcal")
                    .font(.h(12))
                    .foregroundStyle(Color.green)
            }
            .padding(.bottom, 6)
            ForEach(meal.items) { item in
                HStack(spacing: 8) {
                    Circle().fill(Color.hairline2).frame(width: 5, height: 5)
                    Text(item.name)
                        .font(.h(12.5, .bold))
                        .foregroundStyle(Color.inkBody)
                    Spacer(minLength: 6)
                    Text("\(item.portionText) · \(item.grams) g")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.faint)
                    Text("\(item.kcal)")
                        .font(.h(11.5))
                        .foregroundStyle(Color.sub)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    // MARK: Antrenman

    @ViewBuilder
    private var workoutContent: some View {
        if let plan = model.workoutPlan {
            if let session = plan.sessions.first(where: { $0.day == selectedDay }) {
                sessionCard(session)
            } else {
                restCard
            }
            volumeCard(plan)
            noteBox(plan.note)
        } else {
            noteBox("Antrenman planı üretilemedi.")
        }
    }

    private func sessionCard(_ session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.h(15))
                        .foregroundStyle(Color.ink)
                    Text(session.focus)
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                Text("~\(session.minutes) dk")
                    .font(.h(12))
                    .foregroundStyle(Color.coral)
            }
            .padding(.bottom, 8)

            ForEach(session.exercises) { exercise in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.h(12.5, .bold))
                            .foregroundStyle(Color.inkBody)
                        Text("\(exercise.region) · \(exercise.equipment)")
                            .font(.h(10, .bold))
                            .foregroundStyle(Color.faint)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(exercise.sets) × \(exercise.reps)")
                            .font(.h(12.5))
                            .foregroundStyle(Color.coral)
                        Text("\(exercise.restSeconds) sn ara")
                            .font(.h(10, .bold))
                            .foregroundStyle(Color.sub)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.stepPurple)
                Text("Seans sonu \(session.cardioMinutes) dk tempolu yürüyüş")
                    .font(.h(11.5, .bold))
                    .foregroundStyle(Color.inkBody)
                Spacer()
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private var restCard: some View {
        VStack(spacing: 5) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.chevron)
            Text("Dinlenme günü")
                .font(.h(13))
                .foregroundStyle(Color.sub)
            Text("Toparlanma antrenmanın parçası — kas dinlenirken gelişir.")
                .font(.h(11, .semibold))
                .foregroundStyle(Color.faint)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .card(18)
    }

    private func volumeCard(_ plan: WeekWorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Haftalık hacim")
                    .font(.h(13))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(plan.weeklyCardioMinutes) dk kardiyo")
                    .font(.h(10.5, .bold))
                    .foregroundStyle(plan.weeklyCardioMinutes >= 150
                                     ? Color.greenDark : Color.warnOrange)
            }
            FlowLayout(spacing: 6) {
                ForEach(plan.weeklySets.sorted(by: { $0.value > $1.value }), id: \.key) { region, sets in
                    Text("\(region) \(sets) set")
                        .font(.h(10.5, .bold))
                        .foregroundStyle(Color.inkMid)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(Color.bgField))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18)
    }

    private func noteBox(_ text: String) -> some View {
        Text(text)
            .font(.h(11, .semibold))
            .foregroundStyle(Color.sub)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bgField)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

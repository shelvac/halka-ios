import SwiftUI

/// Egzersiz tab root — MacFit-style program builder and live workout mode.
struct WorkoutRootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                switch model.workoutView {
                case .home: WorkoutHomeView()
                case .create: ProgramCreateView()
                case .library: ExerciseLibraryView()
                case .program: ProgramDetailView()
                case .run: WorkoutRunView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }
}

// MARK: - Home

struct WorkoutHomeView: View {
    @Environment(AppModel.self) private var model
    /// Geçmiş günler kapalı başlar — sekme bugünle açılsın.
    @State private var showPast = false
    @State private var showingPlan = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Egzersiz")
                .font(.h(24))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // AI koçun kurduğu haftalık program buraya da yansır — plan
            // yalnızca sonuç ekranında yaşamamalı.
            if let plan = model.workoutPlan {
                todayPlanCard(plan)
                    .padding(.bottom, 14)
            }

            HStack(spacing: 10) {
                Button { model.workoutView = .create } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Program Oluştur")
                            .font(.h(14))
                            .foregroundStyle(.white)
                        Text("Bölge seç, egzersizlerini ekle")
                            .font(.h(10.5, .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.coral)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.coral.opacity(0.28), radius: 7, y: 4)
                }
                .buttonStyle(.plain)

                Button {
                    model.libraryPickMode = false
                    model.workoutView = .library
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Egzersiz Kütüphanesi")
                            .font(.h(14))
                            .foregroundStyle(Color.ink)
                        Text("Bölgeye göre keşfet")
                            .font(.h(10.5, .semibold))
                            .foregroundStyle(Color.sub)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: false, vertical: true)

            Text("Programlarım")
                .font(.h(15))
                .foregroundStyle(Color.ink)
                .padding(.top, 20)
                .padding(.bottom, 10)

            ForEach(model.programs) { program in
                Button {
                    model.selectedProgramID = program.id
                    model.workoutView = .program
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.coralBg)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.coral)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(program.name).font(.h(14)).foregroundStyle(Color.ink)
                            Text("\(program.region) · \(program.level) · \(program.items.count) egzersiz")
                                .font(.h(11, .bold))
                                .foregroundStyle(Color.sub)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color.chevron)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.06), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }

            // Uygulama içi antrenmanlar
            if !model.workoutLog.isEmpty {
                Text("Uygulamadan")
                    .font(.h(15))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                VStack(spacing: 0) {
                    ForEach(Array(model.workoutLog.enumerated()), id: \.element.id) { i, entry in
                        HStack(spacing: 10) {
                            Circle().fill(Color.coral).frame(width: 8, height: 8)
                            Text(entry.title)
                                .font(.h(12.5, .bold))
                                .foregroundStyle(Color.inkSoft)
                            Spacer()
                            Text(entry.meta)
                                .font(.h(11))
                                .foregroundStyle(Color.sub)
                        }
                        .padding(.vertical, 13)
                        .overlay(alignment: .top) {
                            if i > 0 { Rectangle().fill(Color.hairline).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .card(18)
            }

            // Apple Watch/iPhone antrenmanları (US-023).
            //
            // Eskiden 90 günün tamamı düz tek liste hâlinde akıyordu; hepsi
            // aynı güne aitmiş gibi görünüyordu. Artık ekran bugünle açılıyor,
            // geçmiş ayrı ve gün gün — istenmedikçe başka tarih görünmüyor.
            if model.hkConnected {
                appleHealthSection
            }
        }
        .fullScreenCover(isPresented: $showingPlan) {
            PlanResultView(initialTab: .workouts)
        }
    }

    /// Haftalık programdan bugünün seansı — yoksa dinlenme günü.
    private func todayPlanCard(_ plan: WeekWorkoutPlan) -> some View {
        let today = model.todayWeekdayIndex
        let session = plan.sessions.first { $0.day == today }
        return Button { showingPlan = true } label: {
            HStack(spacing: 12) {
                Image(systemName: session == nil ? "moon.zzz.fill" : "figure.strengthtraining.traditional")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(session == nil ? Color.chevron : Color.coral)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session == nil ? "Bugün dinlenme günü" : session!.title)
                        .font(.h(13.5))
                        .foregroundStyle(Color.ink)
                    Text(session == nil
                         ? "Haftalık programın: \(plan.sessions.count) gün antrenman"
                         : "\(session!.focus) · \(session!.exercises.count) hareket · ~\(session!.minutes) dk")
                        .font(.h(10.5, .semibold))
                        .foregroundStyle(Color.sub)
                }
                Spacer()
                Text("Planı aç")
                    .font(.h(11, .bold))
                    .foregroundStyle(Color.coral)
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

    @ViewBuilder
    private var appleHealthSection: some View {
        let past = model.pastWorkoutDays

        HStack {
            Text("Apple Health")
                .font(.h(15))
                .foregroundStyle(Color.ink)
            Spacer()
            Text("Bugün")
                .font(.h(10.5, .bold))
                .foregroundStyle(Color.faint)
        }
        .padding(.top, 18)
        .padding(.bottom, 10)

        if model.todayWorkouts.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Color.chevron)
                Text("Bugün henüz antrenman yok")
                    .font(.h(12, .bold))
                    .foregroundStyle(Color.sub)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .card(18)
        } else {
            dayCard(model.todayWorkouts)
        }

        if !past.isEmpty {
            // Geçmiş kapalı geliyor: "Egzersize girince diğer tarihleri
            // görmemeliyim" — açmak kullanıcının kararı.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showPast.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Geçmiş antrenmanlar")
                        .font(.h(13))
                        .foregroundStyle(Color.ink)
                    Text("\(past.count) gün")
                        .font(.h(10, .bold))
                        .foregroundStyle(Color.sub)
                    Spacer()
                    Image(systemName: showPast ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.chevron)
                }
                .padding(.top, 18)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)

            if showPast {
                ForEach(past, id: \.date) { group in
                    Text(AppModel.workoutDayTitle(group.date))
                        .font(.h(11.5, .bold))
                        .foregroundStyle(Color.sub)
                        .padding(.leading, 4)
                        .padding(.bottom, 6)
                    dayCard(group.items)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private func dayCard(_ items: [HealthKitService.WorkoutSummary]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, workout in
                WorkoutRow(workout: workout)
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
    }
}

// MARK: - Program builder

struct ProgramCreateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            BackRow(label: "Geri") { model.workoutBack() }

            Text("Program Oluştur")
                .font(.h(22))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 0) {
                Text("PROGRAM İSMİ")
                    .font(.h(11))
                    .foregroundStyle(Color.sub)
                    .padding(.bottom, 6)
                TextField("Örn. Karın & Core", text: $model.programDraft.name)
                    .font(.h(14, .bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.bgField)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("HEDEF BÖLGE")
                    .font(.h(11))
                    .foregroundStyle(Color.sub)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                FlowLayout(spacing: 6) {
                    ForEach(Demo.regions.dropFirst(), id: \.self) { region in
                        chip(region, active: model.programDraft.region == region) {
                            model.programDraft.region = region
                        }
                    }
                }

                Text("SEVİYE")
                    .font(.h(11))
                    .foregroundStyle(Color.sub)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                HStack(spacing: 6) {
                    ForEach(Demo.levels, id: \.self) { level in
                        chip(level, active: model.programDraft.level == level) {
                            model.programDraft.level = level
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)

            HStack {
                (Text("Egzersizler ").font(.h(15)).foregroundColor(.ink)
                 + Text("· \(model.programDraft.items.count)").font(.h(15)).foregroundColor(.faint))
                Spacer()
                Button {
                    model.libraryPickMode = true
                    model.workoutView = .library
                } label: {
                    Text("+ Egzersiz Ekle")
                        .font(.h(12))
                        .foregroundStyle(Color.coralDark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.coralBg))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 18)
            .padding(.bottom, 10)

            if model.programDraft.items.isEmpty {
                Text("Henüz egzersiz yok — kütüphaneden ekle.")
                    .font(.h(12, .semibold))
                    .foregroundStyle(Color.faint)
                    .frame(maxWidth: .infinity)
                    .padding(26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.dashBorder, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    )
            } else {
                ForEach(Array(model.programDraft.items.enumerated()), id: \.element.id) { i, exercise in
                    HStack(spacing: 12) {
                        ImagePlaceholder(label: exercise.name)
                            .frame(width: 64, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).font(.h(13)).foregroundStyle(Color.ink)
                            Text("\(exercise.region) · \(exercise.reps)")
                                .font(.h(10.5, .bold))
                                .foregroundStyle(Color.sub)
                        }
                        Spacer()
                        Button { model.removeFromDraft(at: i) } label: {
                            Circle()
                                .fill(Color.bgChip)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(Color.sub)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                    .padding(.bottom, 8)
                }
            }

            let enabled = !model.programDraft.items.isEmpty
            Button { model.saveProgram() } label: {
                Text("Programı Kaydet")
                    .font(.h(14))
                    .foregroundStyle(enabled ? .white : Color.disabledText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(enabled ? Color.coral : Color(hex: 0xE5DFD2))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: enabled ? Color.coral.opacity(0.3) : .clear, radius: 7, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .padding(.top, 14)
        }
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.h(12))
                .foregroundStyle(active ? .white : Color.inkMid)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Capsule().fill(active ? Color.coral : Color.bgField))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Library

struct ExerciseLibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            BackRow(label: model.libraryPickMode ? "Programa dön" : "Egzersiz") {
                model.workoutBack()
            }

            Text("Egzersiz Kütüphanesi")
                .font(.h(22))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)
                .padding(.bottom, 12)

            TextField("Egzersiz ara…", text: $model.libraryQuery)
                .font(.h(13, .semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Demo.regions, id: \.self) { region in
                        let active = model.libraryRegion == region
                        Button { model.libraryRegion = region } label: {
                            Text(region)
                                .font(.h(12))
                                .foregroundStyle(active ? .white : Color.inkMid)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(active ? Color.coral : Color.white))
                                .shadow(color: active ? Color.coral.opacity(0.3) : Color.ink.opacity(0.05),
                                        radius: active ? 5 : 3, y: active ? 3 : 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.bottom, 8)

            ForEach(model.filteredLibrary) { exercise in
                let added = model.isInDraft(exercise)
                HStack(spacing: 12) {
                    ImagePlaceholder(label: exercise.name)
                        .frame(width: 72, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).font(.h(13)).foregroundStyle(Color.ink)
                        Text("\(exercise.region) · \(exercise.reps)")
                            .font(.h(10.5, .bold))
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                    if model.libraryPickMode {
                        Button { model.addToDraft(exercise) } label: {
                            Text(added ? "Eklendi" : "+ Ekle")
                                .font(.h(11.5))
                                .foregroundStyle(added ? Color.greenDark : Color.coralDark)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(added ? Color.greenBg : Color.coralBg))
                        }
                        .buttonStyle(.plain)
                        .disabled(added)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                .padding(.bottom, 8)
            }

            if model.libraryPickMode && !model.programDraft.items.isEmpty {
                Button { model.workoutView = .create } label: {
                    Text("Bitti · \(model.programDraft.items.count) egzersiz seçildi")
                        .font(.h(13))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Program detail

struct ProgramDetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        guard let program = model.selectedProgram else { return AnyView(EmptyView()) }
        return AnyView(VStack(alignment: .leading, spacing: 0) {
            BackRow(label: "Programlarım") { model.workoutBack() }

            Text(program.name)
                .font(.h(22))
                .foregroundStyle(Color.ink)
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(program.region)
                    .font(.h(11))
                    .foregroundStyle(Color.coralDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.coralBg))
                metaChip(program.level)
                metaChip("\(program.items.count) egzersiz")
            }
            .padding(.top, 8)
            .padding(.bottom, 14)

            ForEach(program.items) { exercise in
                HStack(spacing: 12) {
                    ImagePlaceholder(label: exercise.name)
                        .frame(width: 72, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).font(.h(13)).foregroundStyle(Color.ink)
                        Text(exercise.reps)
                            .font(.h(10.5, .bold))
                            .foregroundStyle(Color.sub)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                .padding(.bottom, 8)
            }

            Button { model.startRun() } label: {
                Text("Antrenmana Başla").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .coralButton()
            .padding(.top, 10)
        })
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.h(11))
            .foregroundStyle(Color.inkMid)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white))
            .shadow(color: Color.ink.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - Live workout

struct WorkoutRunView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        guard let program = model.selectedProgram else { return AnyView(EmptyView()) }
        return AnyView(VStack(spacing: 0) {
            // Dark timer card — TimelineView drives the stopwatch each second.
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                VStack(spacing: 4) {
                    Text(program.name.uppercased())
                        .font(.h(12))
                        .foregroundStyle(.white.opacity(0.6))
                        .kerning(1)
                    Text(model.runElapsedText)
                        .font(.system(size: 40, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .kerning(-1)
                    Text("\(model.runDone.count) / \(program.items.count) egzersiz")
                        .font(.h(12))
                        .foregroundStyle(Color.greenSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .background(Color.ink)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.top, 14)

            VStack(spacing: 8) {
                ForEach(Array(program.items.enumerated()), id: \.element.id) { i, exercise in
                    let done = model.runDone.contains(i)
                    Button { model.toggleRunDone(i) } label: {
                        HStack(spacing: 12) {
                            RoundCheck(on: done)
                            ImagePlaceholder(label: exercise.name)
                                .frame(width: 64, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.h(13))
                                    .foregroundStyle(done ? Color.faint : Color.ink)
                                    .strikethrough(done)
                                Text(exercise.reps)
                                    .font(.h(10.5, .bold))
                                    .foregroundStyle(Color.sub)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.ink.opacity(0.05), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)

            Button { model.finishRun() } label: {
                Text("Antrenmanı Bitir").frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .coralButton()
            .padding(.top, 6)
        })
    }
}
